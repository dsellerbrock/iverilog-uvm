#!/usr/bin/env bash
# M9-NFA dual-run compatibility gate (the honesty mechanism from
# docs/conformance/m9_nfa_design_2026-07-19.md).
#
# Every tests/sva_nfa/*.sv is compiled and run TWICE — IVL_SVA_NFA off
# (legacy linear engine) and on (automaton engine) — and the complete
# stdout+stderr verdict streams are diffed exactly (heap-address labels
# normalized). Any divergence fails the gate.
#
# Tests named *_nfa_only.sv use shapes the legacy engine diagnoses as
# sorry: they are compiled flag-on only and their output is compared
# against a hand-computed <name>.gold file; the flag-off compile must
# emit the legacy sorry (loud rejection, never silent).
#
# Usage: PATH=<install>/bin:$PATH bash tests/sva_nfa/run.sh

BIN=$(which iverilog)
DIR=$(dirname "$0")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0

norm() { sed -E 's/0x[0-9a-f]+/0xPTR/g'; }

for sv in "$DIR"/*.sv; do
    name=$(basename "$sv" .sv)
    printf "  %-40s " "$name"
    case "$name" in
    *_nfa_only)
        # Legacy must reject loudly...
        loff=$("$BIN" -g2012 -o "$TMP/$name.off.vvp" "$sv" 2>&1)
        if ! echo "$loff" | grep -q "sorry"; then
            echo "FAIL (legacy no longer sorries -- promote to dual-run)"
            FAIL=$((FAIL+1)); continue
        fi
        # ...and the NFA engine must match the hand-computed gold.
        if ! IVL_SVA_NFA=1 "$BIN" -g2012 -o "$TMP/$name.vvp" "$sv" \
                > "$TMP/$name.cmp" 2>&1; then
            echo "FAIL (flag-on compile failed)"
            head -3 "$TMP/$name.cmp"; FAIL=$((FAIL+1)); continue
        fi
        vvp "$TMP/$name.vvp" 2>&1 | norm > "$TMP/$name.out"
        if diff -u "$DIR/$name.gold" "$TMP/$name.out" > "$TMP/$name.diff"; then
            echo "PASS (nfa-only vs gold)"
            PASS=$((PASS+1))
        else
            echo "FAIL (verdicts differ from gold)"
            head -10 "$TMP/$name.diff"; FAIL=$((FAIL+1))
        fi
        ;;
    *)
        ok=1
        "$BIN" -g2012 -o "$TMP/$name.off.vvp" "$sv" 2>&1 | norm > "$TMP/$name.off.cc" || ok=0
        IVL_SVA_NFA=1 "$BIN" -g2012 -o "$TMP/$name.on.vvp" "$sv" 2>&1 | norm > "$TMP/$name.on.cc" || ok=0
        if [ $ok -ne 1 ]; then
            echo "FAIL (compile failed)"; FAIL=$((FAIL+1)); continue
        fi
        # Engagement check: a parity PASS is only meaningful if the
        # flag-on build really used the automaton engine (its slot
        # state registers appear in the vvp assembly). A test whose
        # shapes must ALL fall back declares NFA-EXPECT-FALLBACK.
        if grep -q "NFA-EXPECT-FALLBACK" "$sv"; then
            if grep -q "_ivl_sva[0-9]*_k0s0" "$TMP/$name.on.vvp"; then
                echo "FAIL (expected fallback but NFA engaged)"
                FAIL=$((FAIL+1)); continue
            fi
        else
            if ! grep -q "_ivl_sva[0-9]*_k0s0" "$TMP/$name.on.vvp"; then
                echo "FAIL (NFA engine never engaged -- parity vacuous)"
                FAIL=$((FAIL+1)); continue
            fi
        fi
        vvp "$TMP/$name.off.vvp" 2>&1 | norm > "$TMP/$name.off.out"
        vvp "$TMP/$name.on.vvp"  2>&1 | norm > "$TMP/$name.on.out"
        if diff -u "$TMP/$name.off.cc" "$TMP/$name.on.cc" > "$TMP/$name.diff" \
           && diff -u "$TMP/$name.off.out" "$TMP/$name.on.out" >> "$TMP/$name.diff"; then
            echo "PASS (verdict parity)"
            PASS=$((PASS+1))
        else
            echo "FAIL (engines diverge)"
            head -10 "$TMP/$name.diff"; FAIL=$((FAIL+1))
        fi
        ;;
    esac
done

echo ""
echo "sva_nfa dual-run: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
