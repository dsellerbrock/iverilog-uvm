#!/bin/bash
#SBATCH --job-name=a3-c07-array-eq-r2
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/c07-array-eq-r2-20261019-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/c07-array-eq-r2-20261019-01/logs/job-%j.out

set -uo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/c07-array-eq-r2-20261019-01
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
TOOL=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2/bin
IVL="$TOOL/iverilog"
VVP="$TOOL/vvp"
SUMMARY="$OUT/summary.txt"
OVERALL=0
mkdir -p "$OUT"

{
  printf 'host=%s\n' "$(hostname)"
  printf 'source_head=%s\n' "$(cat "$RUN_DIR/source-head.txt")"
  "$IVL" -V 2>&1 | head -2
  printf 'iverilog_sha256='
  sha256sum "$IVL" | awk '{print $1}'
  printf 'vvp_sha256='
  sha256sum "$VVP" | awk '{print $1}'
} | tee "$SUMMARY"

file=tests/1800_audit/c07/p07_04_multidimensional_array_equality.sv
for std in 2017 2023; do
  stem="$OUT/${std}-p07_04_multidimensional_array_equality"
  printf 'CASE standard=%s probe=%s\n' "$std" "$file" | tee -a "$SUMMARY"
  if /usr/bin/timeout --kill-after=5s 120s "$IVL" "-g$std" -o "$stem.vvp" "$SRC/$file" >"$stem.compile.log" 2>&1; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf 'COMPILE_RC=%s\n' "$compile_rc" | tee -a "$SUMMARY"
  if [ "$compile_rc" -ne 0 ] && [ "$compile_rc" -ne 124 ] \
      && grep -Eq 'Array .* needs an array index here' "$stem.compile.log"; then
    printf 'RESULT=STANDARD_VALID_MULTIDIMENSIONAL_ARRAY_EQUALITY_REJECTED\n' | tee -a "$SUMMARY"
    cat "$stem.compile.log" | tee -a "$SUMMARY"
    continue
  fi
  if [ "$compile_rc" -ne 0 ] || grep -Eq 'syntax error|error:|sorry:' "$stem.compile.log"; then
    printf 'RESULT=INCONCLUSIVE_COMPILE_FAILURE\n' | tee -a "$SUMMARY"
    cat "$stem.compile.log" | tee -a "$SUMMARY"
    OVERALL=1
    continue
  fi
  if /usr/bin/timeout --kill-after=5s 120s "$VVP" "$stem.vvp" >"$stem.run.log" 2>&1; then
    run_rc=0
  else
    run_rc=$?
  fi
  printf 'RUN_RC=%s\n' "$run_rc" | tee -a "$SUMMARY"
  cat "$stem.run.log" | tee -a "$SUMMARY"
  [ "$run_rc" -eq 0 ] || OVERALL=1
done

printf 'OVERALL_RC=%s\n' "$OVERALL" | tee -a "$SUMMARY"
exit "$OVERALL"
