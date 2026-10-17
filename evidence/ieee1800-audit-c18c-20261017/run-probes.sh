#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${1:?usage: run-probes.sh <output-directory>}
IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}
POS="$ROOT/tests/1800_audit/c18/p18_07_inline_with.sv"
LOCAL_THIS="$ROOT/tests/1800_audit/c18/p18_07_local_this.sv"
mkdir -p "$OUT"
: > "$OUT/results.txt"
fail=0
for edition in 2017 2023; do
    exe="$OUT/p18_07_inline_with.$edition.vvp"
    compile="$OUT/p18_07_inline_with.$edition.compile.log"
    run="$OUT/p18_07_inline_with.$edition.run.log"
    printf '\n=== positive -g%s ===\n' "$edition" | tee -a "$OUT/results.txt"
    set +e
    python3 "$ROOT/scripts/run_with_timeout.py" 60 -- "$IVERILOG" -g"$edition" -o "$exe" "$POS" > "$compile" 2>&1
    rc=$?
    set -e
    printf 'compile_rc=%s\n' "$rc" | tee -a "$OUT/results.txt"
    cat "$compile" | tee -a "$OUT/results.txt"
    if [[ $rc -ne 0 ]]; then
        fail=1
    else
        set +e
        python3 "$ROOT/scripts/run_with_timeout.py" 30 -- "$VVP" "$exe" > "$run" 2>&1
        rc=$?
        set -e
        printf 'run_rc=%s\n' "$rc" | tee -a "$OUT/results.txt"
        cat "$run" | tee -a "$OUT/results.txt"
        if [[ $rc -ne 0 ]] || ! grep -q '^DONE fails=0$' "$run"; then fail=1; fi
    fi
    exe="$OUT/p18_07_local_this.$edition.vvp"
    compile="$OUT/p18_07_local_this.$edition.compile.log"
    run="$OUT/p18_07_local_this.$edition.run.log"
    printf '\n=== isolated local::this -g%s ===\n' "$edition" | tee -a "$OUT/results.txt"
    set +e
    python3 "$ROOT/scripts/run_with_timeout.py" 60 -- "$IVERILOG" -g"$edition" -o "$exe" "$LOCAL_THIS" > "$compile" 2>&1
    rc=$?
    set -e
    printf 'compile_rc=%s\n' "$rc" | tee -a "$OUT/results.txt"
    cat "$compile" | tee -a "$OUT/results.txt"
    if [[ $rc -ne 0 ]]; then
        printf 'GAP local::this rejected at compile time\n' | tee -a "$OUT/results.txt"
        fail=1
    else
        set +e
        python3 "$ROOT/scripts/run_with_timeout.py" 30 -- "$VVP" "$exe" > "$run" 2>&1
        rc=$?
        set -e
        printf 'run_rc=%s\n' "$rc" | tee -a "$OUT/results.txt"
        cat "$run" | tee -a "$OUT/results.txt"
        if [[ $rc -ne 0 ]] || ! grep -q '^DONE local::this$' "$run"; then
            printf 'GAP local::this runtime binding mismatch\n' | tee -a "$OUT/results.txt"
            fail=1
        fi
    fi
    for negative in n18_07_this_unresolved n18_07_scope_randomize_idlist n18_07_scope_randomize_null; do
        compile="$OUT/$negative.$edition.compile.log"
        printf '\n=== negative %s -g%s ===\n' "$negative" "$edition" | tee -a "$OUT/results.txt"
        set +e
        python3 "$ROOT/scripts/run_with_timeout.py" 60 -- "$IVERILOG" -g"$edition" \
            "$ROOT/tests/1800_audit/c18/neg/$negative.sv" > "$compile" 2>&1
        rc=$?
        set -e
        printf 'compile_rc=%s\n' "$rc" | tee -a "$OUT/results.txt"
        cat "$compile" | tee -a "$OUT/results.txt"
        if [[ $rc -eq 0 ]]; then printf 'UNEXPECTED_ACCEPTANCE\n' | tee -a "$OUT/results.txt"; fail=1
        else printf 'EXPECTED_REJECTION\n' | tee -a "$OUT/results.txt"; fi
    done
done
exit "$fail"
