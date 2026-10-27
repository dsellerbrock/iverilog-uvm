#!/bin/bash
#SBATCH --job-name=a3-c16-final
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

files=(
  "tests/1800_audit/c16/p16_14_procedural_assertions.sv"
  "tests/1800_audit/c16/p16_14_restrict_module.sv"
  "tests/1800_audit/c16/p16_14_restrict_procedural.sv"
  "tests/1800_audit/c16/p16_15_disable_resolution.sv"
  "tests/1800_audit/c16/p16_17_expect.sv"
)

for std in 2017 2023; do
    for file in "${files[@]}"; do
        name=$(basename "$file" .sv)
        stem="$OUT/${std}-${name}"
        echo "CASE std=$std file=$file"
        if /usr/bin/timeout --kill-after=5s 120s "$IVL" "-g$std" -gassertions \
            -o "$stem.vvp" "$RUN_DIR/$file" >"$stem.compile.log" 2>&1; then
            compile_rc=0
        else
            compile_rc=$?
        fi
        echo "COMPILE_RC=$compile_rc"
        if [ "$compile_rc" -ne 0 ] || grep -Eq 'syntax error|error:|sorry:' "$stem.compile.log"; then
            echo "COMPILE_DIAGNOSTIC=1"
            continue
        fi
        if /usr/bin/timeout --kill-after=5s 120s "$VVP" "$stem.vvp" \
            >"$stem.run.log" 2>&1; then
            run_rc=0
        else
            run_rc=$?
        fi
        echo "RUN_RC=$run_rc"
    done
done

echo "PROBE_SWEEP_COMPLETE"
