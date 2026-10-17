#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp3-final-wall-r2
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-final-wall-20261015-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-final-wall-20261015-r2/logs/%x-%j.out

set -euo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-final-wall-20261015-r2
BUILD=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build
SOURCE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/reference/source
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
RESULTS="$RUN_DIR/results"
REF="$BUILD/reference/install/bin/vvp"
CAND="$BUILD/candidate/install/bin/vvp"
IVERILOG="$BUILD/reference/install/bin/iverilog"
IVERILOG_VPI="$BUILD/reference/install/bin/iverilog-vpi"
UVM_DPI=$(find "$BUILD/reference/install" -type f -name uvm_dpi.vpi -print -quit)

mkdir -p "$RUN_DIR/logs" "$RESULTS"
printf 'measurement_base=%s\n' "$BASE" > "$RUN_DIR/measurement-base.txt"
for exe in "$REF" "$CAND" "$IVERILOG" "$IVERILOG_VPI"; do test -x "$exe"; done
test -n "$UVM_DPI" && test -s "$UVM_DPI"
test -f "$SOURCE/benchmarks/sim-hotspots/run.sh"
{
  hostname
  uname -a
  printf 'measurement_base=%s\n' "$BASE"
  "$REF" -V | head -n 1
  "$CAND" -V | head -n 1
  sha256sum "$REF" "$CAND" "$IVERILOG"
} > "$RUN_DIR/environment.txt"

PATH="$(dirname "$IVERILOG"):$PATH" \
IVERILOG="$IVERILOG" \
IVERILOG_VPI="$IVERILOG_VPI" \
UVM_DPI="$UVM_DPI" \
  bash "$SOURCE/benchmarks/sim-hotspots/run.sh" --json "$REF" "$CAND" 3 \
  > "$RESULTS/wall-3.json"
sha256sum "$RESULTS/wall-3.json" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/DONE"
