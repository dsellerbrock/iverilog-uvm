#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-10-incdec
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-10-incdec-20261019-28
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-10-incdec-20261019-28/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-10-incdec-20261019-28
TOOLCHAIN=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2
RESULTS="$RUN_DIR/results"
mkdir -p "$RESULTS"
printf 'job_id=%s\nhost=%s\ntoolchain_source=c31cbf1b52f1a39d5775f276e2340525a444a79e\nstarted=%s\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" | tee "$RESULTS/metadata.txt"
sha256sum "$RUN_DIR/input"/*.sv "$TOOLCHAIN/bin/iverilog" "$TOOLCHAIN/bin/vvp" | tee "$RESULTS/sha256.txt"
for edition in 2017 2023; do
  stem="p16_10_incdec_match_item-$edition"
  set +e
  timeout --signal=TERM --kill-after=5s 120s "$TOOLCHAIN/bin/iverilog" -B "$TOOLCHAIN/lib/ivl" -g"$edition" -gassertions -s test -o "$RESULTS/$stem.vvp" "$RUN_DIR/input/p16_10_incdec_match_item.sv" > "$RESULTS/$stem.compile.log" 2>&1
  compile_rc=$?
  printf 'compile_exit=%s\n' "$compile_rc" >> "$RESULTS/$stem.compile.log"
  run_rc=NA
  if test "$compile_rc" -eq 0; then
    timeout --signal=TERM --kill-after=5s 120s "$TOOLCHAIN/bin/vvp" -n "$RESULTS/$stem.vvp" > "$RESULTS/$stem.run.log" 2>&1
    run_rc=$?
    printf 'run_exit=%s\n' "$run_rc" >> "$RESULTS/$stem.run.log"
  fi
  set -e
  printf 'edition=%s compile_exit=%s run_exit=%s\n' "$edition" "$compile_rc" "$run_rc" | tee -a "$RESULTS/metadata.txt"
done
printf 'finished=%s\n' "$(date -Is)" >> "$RESULTS/metadata.txt"
