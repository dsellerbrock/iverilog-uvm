#!/usr/bin/env bash
#SBATCH --job-name=a3-dpi-focus
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=00:15:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01/logs/%x-%j.out
set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/dpi-context-probe-20261013-01
INSTALL="$RUN_DIR/install"
UVM="$RUN_DIR/input/uvm"
TEST="$RUN_DIR/input/uvm_files.sv"
EXPECTED_TREE=2cb6260f02c1680196cca51d76e6e429e3b738d5
TEST_SHA=b5e124466f7f2f9ee3139aa1000039eb15d74cfaf96cf5db8b0b40dd6ef4407b
test "$(git -C "$RUN_DIR/source" rev-parse HEAD^{tree})" = "$EXPECTED_TREE"
echo "$TEST_SHA  $TEST" | sha256sum -c -
mkdir -p "$RUN_DIR/evidence"
{
  hostname
  date -u
  "$INSTALL/bin/iverilog" -V
  sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp"
} > "$RUN_DIR/evidence/focused-environment.txt" 2>&1
set +e
timeout --signal=TERM --kill-after=2s 120s "$INSTALL/bin/iverilog" -g2012 -o "$RUN_DIR/evidence/uvm_files.out" -I "$UVM/src" -I "$RUN_DIR/input" "$UVM/src/uvm_pkg.sv" "$TEST" > "$RUN_DIR/logs/focused.log" 2>&1
rc=$?
set -e
printf 'compile_rc=%s\n' "$rc" >> "$RUN_DIR/logs/provenance.txt"
if grep -F 'uvm_hdl.svh:77: syntax error' "$RUN_DIR/logs/focused.log"; then
  echo 'BASELINE_REPRODUCED' | tee "$RUN_DIR/evidence/result.txt"
else
  echo 'BASELINE_DID_NOT_MATCH' | tee "$RUN_DIR/evidence/result.txt"
  cat "$RUN_DIR/logs/focused.log"
  exit 2
fi
