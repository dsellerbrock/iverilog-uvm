#!/usr/bin/env bash
# Hard regression gate over the vendored ivtest suite (manifesto Phase 0).
#
# Runs the full vvp_reg.pl sweep and name-diffs the failing set against
# the committed expectation list. The gate FAILS on any difference in
# EITHER direction:
#   - a test failing that is not in the list  -> new, unexplained
#     regression; fix it or (only with a written reason) add it.
#   - a listed test that now passes           -> stale entry; remove it
#     in the same PR so the expectation list always states the truth.
#
# Every name in the expectation list carries a category comment in
# docs/conformance/ (baseline + audit); nothing is allowed to fail
# without a written reason. Also hard-gates the bundled VPI suite,
# the negative suite, and malformed-bytecode runtime invariants.
#
# Usage: ./.github/ivtest_gate.sh   (from the repository root)

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
EXPECT="$ROOT/docs/conformance/ivtest_expected_fails.list"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

status=0

echo "=== ivtest sweep (vendored suite) ==="
cd "$ROOT/ivtest"
perl vvp_reg.pl > "$WORK/ivtest.log" 2>&1
tail -3 "$WORK/ivtest.log"

grep -E "==> Failed|Failed - missing" "$WORK/ivtest.log" \
    | awk -F: '{gsub(/ /,"",$1); print $1}' | sort -u > "$WORK/actual.txt"
grep -vE "^#|^\s*$" "$EXPECT" | awk '{print $1}' | sort -u > "$WORK/expected.txt"

new_fails=$(comm -23 "$WORK/actual.txt" "$WORK/expected.txt")
stale=$(comm -13 "$WORK/actual.txt" "$WORK/expected.txt")

if [ -n "$new_fails" ]; then
    echo ""
    echo "GATE FAIL: unexplained new ivtest failures:"
    echo "$new_fails" | sed 's/^/  /'
    echo "Each must be fixed, or added to $EXPECT with a documented reason."
    status=1
fi
if [ -n "$stale" ]; then
    echo ""
    echo "GATE FAIL: stale expectation entries (these tests now PASS):"
    echo "$stale" | sed 's/^/  /'
    echo "Remove them from $EXPECT in this PR so the list stays truthful."
    status=1
fi
[ $status -eq 0 ] && echo "ivtest name-diff gate: clean ($(wc -l < "$WORK/actual.txt") expected failures, 0 unexplained)"

echo ""
echo "=== bundled VPI suite ==="
perl vpi_reg.pl > "$WORK/vpi.log" 2>&1
tail -1 "$WORK/vpi.log"
if ! grep -qE "Total=[0-9]+, Passed=[0-9]+, Failed=0, Not Implemented=0" "$WORK/vpi.log" \
   || ! awk -F'[=,]' '/Test results/ { exit !($2 == $4) }' "$WORK/vpi.log"; then
    echo "GATE FAIL: bundled VPI suite has failures (Total must equal Passed, Failed must be 0)."
    status=1
fi

echo ""
echo "=== negative suite ==="
cd "$ROOT"
if ! bash tests/negative/run_negative.sh > "$WORK/neg.log" 2>&1; then
    tail -5 "$WORK/neg.log"
    echo "GATE FAIL: negative suite has failures."
    status=1
else
    tail -1 "$WORK/neg.log"
fi

echo ""
echo "=== VVP runtime invariants ==="
runtime_vvp=$(command -v vvp 2>/dev/null || true)
runtime_iverilog=$(command -v iverilog 2>/dev/null || true)
if [ -z "$runtime_vvp" ] || [ -z "$runtime_iverilog" ] \
   || ! VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_rand_mode_stack_underflow.sh \
        > "$WORK/vvp-runtime.log" 2>&1 \
   || ! VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_darray_default_fill_malformed.sh \
        >> "$WORK/vvp-runtime.log" 2>&1 \
   || ! VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_concat_malformed_arity.sh \
        >> "$WORK/vvp-runtime.log" 2>&1 \
   || ! VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_dist_ir_compat.sh \
        >> "$WORK/vvp-runtime.log" 2>&1 \
   || ! VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_covgrp_metadata.sh \
        >> "$WORK/vvp-runtime.log" 2>&1 \
   || ! IVERILOG="$runtime_iverilog" VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_covgrp_options_report.sh \
        >> "$WORK/vvp-runtime.log" 2>&1 \
   || ! VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_vif_indexed_wait_malformed.sh \
        >> "$WORK/vvp-runtime.log" 2>&1 \
   || ! VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_force_array_runtime.sh \
        >> "$WORK/vvp-runtime.log" 2>&1 \
   || ! VVP="$runtime_vvp" \
        bash tests/vvp_runtime/run_queue_slice_legacy.sh \
        >> "$WORK/vvp-runtime.log" 2>&1; then
    cat "$WORK/vvp-runtime.log" 2>/dev/null || true
    echo "GATE FAIL: VVP bytecode invariant failed."
    status=1
else
    tail -1 "$WORK/vvp-runtime.log"
fi

exit $status
