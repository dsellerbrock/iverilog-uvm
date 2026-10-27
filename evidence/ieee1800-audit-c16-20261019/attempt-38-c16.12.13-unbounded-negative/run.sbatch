#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-12-eventually-neg
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-eventually-neg-20261019-38
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-eventually-neg-20261019-38/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-eventually-neg-20261019-38
TOOLCHAIN=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2
RESULTS="$RUN_DIR/results"
IVERILOG="$TOOLCHAIN/bin/iverilog"
mkdir -p "$RESULTS"
printf 'job_id=%s\nhost=%s\nsource_head=27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e\ntoolchain_source=c31cbf1b52f1a39d5775f276e2340525a444a79e\nstarted=%s\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" | tee "$RESULTS/metadata.txt"
sha256sum "$RUN_DIR/input/n16_12_13_unbounded_eventually.sv" "$IVERILOG" | tee "$RESULTS/sha256.txt"
failed=0
for edition in 2017 2023; do
  set +e
  timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$TOOLCHAIN/lib/ivl" -g"$edition" -gassertions -s test -o "$RESULTS/n16_12_13_unbounded_eventually-$edition.vvp" "$RUN_DIR/input/n16_12_13_unbounded_eventually.sv" > "$RESULTS/n16_12_13_unbounded_eventually-$edition.compile.log" 2>&1
  compile_rc=$?
  printf 'compile_exit=%s\n' "$compile_rc" >> "$RESULTS/n16_12_13_unbounded_eventually-$edition.compile.log"
  set -e
  if test "$compile_rc" -ne 0 && grep -Fq "unbounded \`eventually' is not legal" "$RESULTS/n16_12_13_unbounded_eventually-$edition.compile.log"; then
    outcome=EXPECTED_REJECTION
  else
    outcome=UNEXPECTED_RESULT
    failed=1
  fi
  printf 'edition=%s compile_exit=%s outcome=%s\n' "$edition" "$compile_rc" "$outcome" | tee -a "$RESULTS/metadata.txt"
done
printf 'finished=%s\n' "$(date -Is)" >> "$RESULTS/metadata.txt"
exit "$failed"
