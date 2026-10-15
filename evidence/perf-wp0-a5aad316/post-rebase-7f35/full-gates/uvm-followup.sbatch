#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp0-uvm-7f35
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-1174ea06-7f35-20261014-r1/logs/%x-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-1174ea06-7f35-20261014-r1/logs/%x-%j.err
set -euo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-1174ea06-7f35-20261014-r1
SRC="$RUN/source-off"
INSTALL="$RUN/install-off"
mkdir -p "$RUN/logs"
export PATH="$INSTALL/bin:$PATH"
export IVERILOG="$INSTALL/bin/iverilog"
export VVP="$INSTALL/bin/vvp"
unset IVL_PERF_STATS

set +e
/usr/bin/time -v -o "$RUN/logs/uvm-followup.resource" \
  timeout --signal=TERM --kill-after=15s 10800s \
  bash -c 'cd "$1" && bash .github/uvm_test.sh' bash "$SRC" \
  > "$RUN/logs/uvm-followup.log" 2>&1
rc=$?
set -e
printf 'exit_code=%s\n' "$rc" > "$RUN/logs/uvm-followup.status"
if [[ "$rc" -ne 0 ]]; then
  printf 'UVM follow-up exited %s\n' "$rc" >&2
  exit "$rc"
fi
grep -F 'DPI mode: REAL DPI umbrella loaded' "$RUN/logs/uvm-followup.log" \
  > "$RUN/logs/uvm-dpi-proof.txt"
if grep -Fq 'FALLBACK' "$RUN/logs/uvm-followup.log"; then
  printf 'UVM runner reported fallback DPI\n' >&2
  exit 1
fi
grep -E 'UVM regression: [0-9]+ passed, 0 failed, [0-9]+ skipped' \
  "$RUN/logs/uvm-followup.log" > "$RUN/logs/uvm-summary.txt"
printf 'followup_job=%s\nresult=PASS\n' "$SLURM_JOB_ID" \
  > "$RUN/logs/uvm-followup.aggregate.txt"
sha256sum "$RUN/logs/uvm-followup.log" "$RUN/logs/uvm-followup.resource" \
  "$RUN/logs/uvm-followup.status" "$RUN/logs/uvm-dpi-proof.txt" \
  "$RUN/logs/uvm-summary.txt" "$RUN/logs/uvm-followup.aggregate.txt" \
  > "$RUN/logs/uvm-followup.sha256"
