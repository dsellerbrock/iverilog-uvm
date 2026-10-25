#!/bin/bash
#SBATCH --job-name=a3-c16-14-19
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00
#SBATCH --output=logs/%x-%j.out

set -u
RUN_DIR=$(pwd)
OUT="$RUN_DIR/results"
TOOL=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2/bin
IVL="$TOOL/iverilog"
VVP="$TOOL/vvp"
mkdir -p "$OUT"
failures=0

run_case() {
    std=$1
    file=$2
    expected=$3
    name=$(basename "$file" .sv)
    stem="$OUT/${std}-${name}"
    echo "CASE std=$std file=$file expected=$expected"

    if /usr/bin/timeout --kill-after=5s 120s "$IVL" "-g$std" -gassertions \
        -o "$stem.vvp" "$RUN_DIR/$file" >"$stem.compile.log" 2>&1; then
        compile_rc=0
    else
        compile_rc=$?
    fi
    echo "COMPILE_RC=$compile_rc"

    if [ "$expected" = reject ]; then
        if [ "$compile_rc" -eq 0 ] && ! grep -Eq 'syntax error|error:|sorry:' "$stem.compile.log"; then
            echo "UNEXPECTED_COMPILE_ACCEPT"
            failures=$((failures + 1))
        else
            echo "EXPECTED_COMPILE_REJECT"
        fi
        return
    fi

    if [ "$compile_rc" -ne 0 ] || grep -Eq 'syntax error|error:|sorry:' "$stem.compile.log"; then
        echo "UNEXPECTED_COMPILE_REJECT"
        failures=$((failures + 1))
        return
    fi

    if /usr/bin/timeout --kill-after=5s 120s "$VVP" "$stem.vvp" \
        >"$stem.run.log" 2>&1; then
        run_rc=0
    else
        run_rc=$?
    fi
    echo "RUN_RC=$run_rc"
    if [ "$run_rc" -ne 0 ]; then
        echo "UNEXPECTED_RUN_FAILURE"
        failures=$((failures + 1))
    fi
}

files=(
  "tests/1800_audit/c16/p16_12_14_abort_boolean.sv:run"
  "tests/1800_audit/c16/p16_12_14_abort_temporal.sv:reject"
  "tests/1800_audit/c16/p16_12_15_strength.sv:run"
  "tests/1800_audit/c16/p16_12_17_recursive.sv:run"
  "tests/1800_audit/c16/p16_12_18_untyped_formal_decl.sv:run"
  "tests/1800_audit/c16/p16_12_18_untyped_formal_instance.sv:run"
  "tests/1800_audit/c16/p16_12_18_typed_formal.sv:reject"
  "tests/1800_audit/c16/p16_12_19_local_formal.sv:reject"
  "tests/1800_audit/c16/n16_12_19_local_output_formal.sv:reject"
)

for std in 2017 2023; do
    for entry in "${files[@]}"; do
        file=${entry%:*}
        expected=${entry##*:}
        run_case "$std" "$file" "$expected"
    done
done

echo "TOTAL_UNEXPECTED=$failures"
exit "$((failures != 0))"
