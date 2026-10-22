#!/bin/bash
#SBATCH --job-name=a3-c07-struct-union
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/c07-struct-union-20261019-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/c07-struct-union-20261019-01/logs/job-%j.out

set -uo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/c07-struct-union-20261019-01
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
TOOL=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2/bin
IVL="$TOOL/iverilog"
VVP="$TOOL/vvp"
RESULTS="$OUT/summary.txt"
OVERALL=0

mkdir -p "$OUT"
{
  printf 'host=%s\n' "$(hostname)"
  printf 'source_head=%s\n' "$(cat "$RUN_DIR/source-head.txt")"
  printf 'compiler_version=\n'
  "$IVL" -V 2>&1 | head -2
  printf 'iverilog_sha256='
  sha256sum "$IVL" | awk '{print $1}'
  printf 'vvp_sha256='
  sha256sum "$VVP" | awk '{print $1}'
} | tee "$RESULTS"

run_positive() {
  std="$1"
  file="$2"
  stem="$OUT/${std}-$(basename "$file" .sv)"
  printf 'CASE standard=%s probe=%s\n' "$std" "$file" | tee -a "$RESULTS"
  if /usr/bin/timeout --kill-after=5s 120s "$IVL" "-g$std" -o "$stem.vvp" "$SRC/$file" >"$stem.compile.log" 2>&1; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf 'COMPILE_RC=%s\n' "$compile_rc" | tee -a "$RESULTS"
  if [ "$compile_rc" -ne 0 ] || grep -Eq 'syntax error|error:|sorry:' "$stem.compile.log"; then
    printf 'COMPILE_DIAGNOSTIC=\n' | tee -a "$RESULTS"
    cat "$stem.compile.log" | tee -a "$RESULTS"
    OVERALL=1
    return
  fi
  if /usr/bin/timeout --kill-after=5s 120s "$VVP" "$stem.vvp" >"$stem.run.log" 2>&1; then
    run_rc=0
  else
    run_rc=$?
  fi
  printf 'RUN_RC=%s\n' "$run_rc" | tee -a "$RESULTS"
  cat "$stem.run.log" | tee -a "$RESULTS"
  [ "$run_rc" -eq 0 ] || OVERALL=1
}

for std in 2017 2023; do
  run_positive "$std" tests/1800_audit/c07/p07_02_structures.sv
  run_positive "$std" tests/1800_audit/c07/p07_03_untagged_unions.sv
  run_positive "$std" tests/1800_audit/c07/p07_03_02_tagged_unions.sv
done

# IEEE 1800-2023 adds soft packed unions; the same syntax is expected to be
# rejected under the 2017 edition.
soft_file=tests/1800_audit/c07/p07_03_1_soft_packed_union_2023.sv
soft_stem="$OUT/2017-p07_03_1_soft_packed_union_2023"
printf 'CASE standard=2017 expected=reject probe=%s\n' "$soft_file" | tee -a "$RESULTS"
if /usr/bin/timeout --kill-after=5s 120s "$IVL" -g2017 -o "$soft_stem.vvp" "$SRC/$soft_file" >"$soft_stem.compile.log" 2>&1; then
  printf 'RESULT=UNEXPECTED_ACCEPT\n' | tee -a "$RESULTS"
  OVERALL=1
else
  compile_rc=$?
  if [ "$compile_rc" -ne 124 ] && grep -Eq 'syntax error|error:|sorry:' "$soft_stem.compile.log"; then
    printf 'RESULT=EXPECTED_COMPILE_REJECTION rc=%s\n' "$compile_rc" | tee -a "$RESULTS"
  else
    printf 'RESULT=INCONCLUSIVE_COMPILE_REJECTION rc=%s\n' "$compile_rc" | tee -a "$RESULTS"
    cat "$soft_stem.compile.log" | tee -a "$RESULTS"
    OVERALL=1
  fi
fi

run_positive 2023 "$soft_file"
printf 'OVERALL_RC=%s\n' "$OVERALL" | tee -a "$RESULTS"
exit "$OVERALL"
