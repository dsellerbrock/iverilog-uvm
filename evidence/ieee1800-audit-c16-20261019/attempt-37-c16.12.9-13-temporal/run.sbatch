#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-12-temporal
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-temporal-20261019-37
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-temporal-20261019-37/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-12-temporal-20261019-37
TOOLCHAIN=/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2
RESULTS="$RUN_DIR/results"
IVERILOG="$TOOLCHAIN/bin/iverilog"
VVP="$TOOLCHAIN/bin/vvp"
mkdir -p "$RESULTS"
printf 'job_id=%s\nhost=%s\nsource_head=27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e\ntoolchain_source=c31cbf1b52f1a39d5775f276e2340525a444a79e\nstarted=%s\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" | tee "$RESULTS/metadata.txt"
sha256sum "$RUN_DIR/input"/*.sv "$RUN_DIR/input"/neg/*.sv "$IVERILOG" "$VVP" | tee "$RESULTS/sha256.txt"
failed=0
run_positive() {
  input="$1"; stem="${input%.sv}"; edition="$2"
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
  printf 'positive=%s edition=%s compile_exit=%s run_exit=%s\n' "$input" "$edition" "$compile_rc" "$run_rc" | tee -a "$RESULTS/metadata.txt"
  if test "$compile_rc" -ne 0 || test "$run_rc" -ne 0; then failed=1; fi
}
run_unbounded_negative() {
  edition="$1"
  set +e
  timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$TOOLCHAIN/lib/ivl" -g"$edition" -gassertions -s test -o "$RESULTS/n16_12_13_unbounded_eventually-$edition.vvp" "$RUN_DIR/input/neg/n16_12_13_unbounded_eventually.sv" > "$RESULTS/n16_12_13_unbounded_eventually-$edition.compile.log" 2>&1
  compile_rc=$?
  printf 'compile_exit=%s\n' "$compile_rc" >> "$RESULTS/n16_12_13_unbounded_eventually-$edition.compile.log"
  set -e
  if test "$compile_rc" -ne 0 && grep -Fq "unbounded \`eventually' is not legal" "$RESULTS/n16_12_13_unbounded_eventually-$edition.compile.log"; then
    outcome=EXPECTED_REJECTION
  else
    outcome=UNEXPECTED_RESULT
    failed=1
  fi
  printf 'negative=n16_12_13_unbounded_eventually.sv edition=%s compile_exit=%s outcome=%s\n' "$edition" "$compile_rc" "$outcome" | tee -a "$RESULTS/metadata.txt"
}
for edition in 2017 2023; do
  run_positive p16_12_09_followed_by.sv "$edition"
  run_positive p16_12_10_nexttime.sv "$edition"
  run_positive p16_12_11_always.sv "$edition"
  run_positive p16_12_12_until.sv "$edition"
  run_positive p16_12_13_eventually.sv "$edition"
  run_unbounded_negative "$edition"
done
printf 'finished=%s\n' "$(date -Is)" >> "$RESULTS/metadata.txt"
exit "$failed"
