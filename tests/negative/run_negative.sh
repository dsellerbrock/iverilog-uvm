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
    # Tests marked NEG-LEGACY-ONLY exercise a construct the (now default)
    # automaton engine LOWERS but the legacy linear engine rejects; run
    # them against the legacy engine so they still verify the loud legacy
    # rejection (the automaton path is covered by a positive gold test).
    env_pfx=""
    if grep -q "NEG-LEGACY-ONLY" "$sv"; then env_pfx="IVL_SVA_LEGACY=1"; fi
    out=$(env $env_pfx "$BIN" -g2012 -o /dev/null "$sv" 2>&1)
    status=$?
    # A rejection is valid if the compile fails (non-zero exit) with a
    # loud diagnostic. The fork uses both "error:" (illegal input) and
    # "sorry:" (deliberately-unsupported construct) as loud diagnostics
    # per the manifesto; either counts as a proper rejection.
    if [ $status -ne 0 ] && echo "$out" | grep -qiE "error|sorry"; then
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
