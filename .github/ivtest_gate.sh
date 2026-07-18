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
# without a written reason. Also hard-gates the bundled VPI suite
# (81/81) and the negative suite.
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
if ! grep -qE "Total=81, Passed=81, Failed=0" "$WORK/vpi.log"; then
    echo "GATE FAIL: bundled VPI suite is not 81/81."
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

exit $status
