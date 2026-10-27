#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-12-combinators-r4
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-combinators-20261019-36
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-combinators-20261019-36/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-combinators-20261019-36
TOOLCHAIN=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2
RESULTS="$RUN_DIR/results"
IVERILOG="$TOOLCHAIN/bin/iverilog"
VVP="$TOOLCHAIN/bin/vvp"
mkdir -p "$RESULTS"
printf 'job_id=%s\nhost=%s\nsource_head=27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e\ntoolchain_source=c31cbf1b52f1a39d5775f276e2340525a444a79e\nstarted=%s\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" | tee "$RESULTS/metadata.txt"
sha256sum "$RUN_DIR/input"/*.sv "$IVERILOG" "$VVP" | tee "$RESULTS/sha256.txt"
failed=0
run_probe() {
  input="$1"; stem="$2"; edition="$3"
  set +e
  timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$TOOLCHAIN/lib/ivl" -g"$edition" -gassertions -s test -o "$RESULTS/$stem-$edition.vvp" "$RUN_DIR/input/$input" > "$RESULTS/$stem-$edition.compile.log" 2>&1
  compile_rc=$?
  printf 'compile_exit=%s\n' "$compile_rc" >> "$RESULTS/$stem-$edition.compile.log"
  run_rc=NA
  if test "$compile_rc" -eq 0; then
    timeout --signal=TERM --kill-after=5s 120s "$VVP" -n "$RESULTS/$stem-$edition.vvp" > "$RESULTS/$stem-$edition.run.log" 2>&1
    run_rc=$?
    printf 'run_exit=%s\n' "$run_rc" >> "$RESULTS/$stem-$edition.run.log"
  fi
  set -e
  printf 'input=%s edition=%s compile_exit=%s run_exit=%s\n' "$input" "$edition" "$compile_rc" "$run_rc" | tee -a "$RESULTS/metadata.txt"
  if test "$compile_rc" -ne 0 || test "$run_rc" -ne 0; then failed=1; fi
}
for edition in 2017 2023; do
  run_probe p16_12_04_05_property_and_or.sv p16_12_04_05 "$edition"
  run_probe p16_12_08_implies_iff.sv p16_12_08 "$edition"
  run_probe p16_12_16_case.sv p16_12_16 "$edition"
done
printf 'finished=%s\n' "$(date -Is)" >> "$RESULTS/metadata.txt"
exit "$failed"
