#!/usr/bin/env bash
#SBATCH --job-name=a3-dpi-case
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01/logs/%x-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01
INSTALL="$RUN_DIR/install"
UVM="$RUN_DIR/input/uvm"
TEST="$RUN_DIR/input/16.10--property-local-var-uvm.sv"
TEST_SHA=43f638a3f06492a85ae183b3290b4116fad35802b891cdfde4bdf1f8a9a24a1a
echo "$TEST_SHA  $TEST" | sha256sum -c -
set +e
timeout --signal=TERM --kill-after=2s 120s "$INSTALL/bin/iverilog" -g2012 -o "$RUN_DIR/evidence/property-local-var-uvm.out" -I "$UVM/src" -I "$RUN_DIR/input" "$UVM/src/uvm_pkg.sv" "$TEST" > "$RUN_DIR/logs/case-actual.log" 2>&1
rc=$?
set -e
printf 'case_compile_rc=%s\n' "$rc" | tee "$RUN_DIR/evidence/case-result.txt"
cat "$RUN_DIR/logs/case-actual.log"
