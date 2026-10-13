#!/usr/bin/env bash
#SBATCH --job-name=a3-event-control
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-corrected-20261013-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-corrected-20261013-01/logs/event-trigger-control-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/svtests-corrected-20261013-01
INSTALL="$RUN_DIR/install"
TEST="$RUN_DIR/input/event-trigger-after-waiter-ready.sv"
OUT="$RUN_DIR/evidence/event-trigger-after-waiter-ready.out"
export LD_LIBRARY_PATH="$INSTALL/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
timeout --signal=TERM --kill-after=2s 120s "$INSTALL/bin/iverilog" -g2012 -o "$OUT" "$TEST"
set +e
timeout --signal=TERM --kill-after=2s 120s "$INSTALL/bin/vvp" "$OUT" > "$RUN_DIR/logs/event-trigger-after-waiter-ready.log" 2>&1
rc=$?
set -e
printf 'vvp_rc=%s\n' "$rc" | tee "$RUN_DIR/evidence/event-trigger-control-result.txt"
cat "$RUN_DIR/logs/event-trigger-after-waiter-ready.log"
test "$rc" -eq 0
grep -Fq ':assert: (1 == 1)' "$RUN_DIR/logs/event-trigger-after-waiter-ready.log"
