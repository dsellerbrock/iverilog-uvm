#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${1:?usage: run-probes.sh <output-directory>}
IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}
mkdir -p "$OUT"
POS="$ROOT/tests/1800_audit/c18/p18_06_methods.sv"
NEG="$ROOT/tests/1800_audit/c18/neg/n18_06_override_randomize.sv"
TIMEOUT="$ROOT/scripts/run_with_timeout.py"
: > "$OUT/results.txt"
fail=0
for edition in 2017 2023; do
    exe="$OUT/p18_06_methods.$edition.vvp"
    compile="$OUT/p18_06_methods.$edition.compile.log"
    run="$OUT/p18_06_methods.$edition.run.log"
    printf '\n=== positive -g%s ===\n' "$edition" | tee -a "$OUT/results.txt"
    set +e
    python3 "$TIMEOUT" 60 -- "$IVERILOG" -g"$edition" -o "$exe" "$POS" > "$compile" 2>&1
    rc=$?
    set -e
    printf 'compile_rc=%s\n' "$rc" | tee -a "$OUT/results.txt"
    cat "$compile" | tee -a "$OUT/results.txt"
    if [[ $rc -ne 0 ]]; then fail=1; continue; fi
    set +e
    python3 "$TIMEOUT" 30 -- "$VVP" "$exe" > "$run" 2>&1
    rc=$?
    set -e
    printf 'run_rc=%s\n' "$rc" | tee -a "$OUT/results.txt"
    cat "$run" | tee -a "$OUT/results.txt"
    if [[ $rc -ne 0 ]] || ! grep -q '^DONE fails=0$' "$run"; then fail=1; fi

    exe="$OUT/n18_06_override_randomize.$edition.vvp"
    compile="$OUT/n18_06_override_randomize.$edition.compile.log"
    printf '\n=== negative -g%s ===\n' "$edition" | tee -a "$OUT/results.txt"
    set +e
    python3 "$TIMEOUT" 60 -- "$IVERILOG" -g"$edition" -o "$exe" "$NEG" > "$compile" 2>&1
    rc=$?
    set -e
    printf 'compile_rc=%s\n' "$rc" | tee -a "$OUT/results.txt"
    cat "$compile" | tee -a "$OUT/results.txt"
    if [[ $rc -eq 0 ]]; then printf 'UNEXPECTED_ACCEPTANCE\n' | tee -a "$OUT/results.txt"; fail=1
    else printf 'EXPECTED_REJECTION\n' | tee -a "$OUT/results.txt"; fi
done
exit "$fail"
