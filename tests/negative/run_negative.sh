#!/usr/bin/env bash
# Negative-test runner: each tests/negative/*.sv must FAIL to compile
# and the diagnostic must mention the marker embedded in the file name
# or a generic error. A test that compiles cleanly is a FAILURE of the
# suite (silent acceptance of illegal input — manifesto principle 4).
#
# Usage: PATH=<install>/bin:$PATH bash tests/negative/run_negative.sh

BIN=$(which iverilog)
DIR=$(dirname "$0")
PASS=0
FAIL=0

for sv in "$DIR"/*.sv; do
    name=$(basename "$sv" .sv)
    printf "  %-40s " "$name"
    out=$("$BIN" -g2012 -o /dev/null "$sv" 2>&1)
    status=$?
    if [ $status -ne 0 ] && echo "$out" | grep -qiE "error"; then
        echo "PASS (rejected with diagnostic)"
        PASS=$((PASS+1))
    else
        echo "FAIL (accepted or no diagnostic)"
        echo "$out" | head -3
        FAIL=$((FAIL+1))
    fi
done

echo ""
echo "Negative tests: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
