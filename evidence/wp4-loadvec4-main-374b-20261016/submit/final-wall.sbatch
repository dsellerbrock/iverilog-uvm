#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp4-final-wall
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-final-wall-374b-20261016-r1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-final-wall-374b-20261016-r1/logs/%x-%j.out

set -euo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-final-wall-374b-20261016-r1
SCREEN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r2
SOURCE="$SCREEN_DIR/source/reference"
REF="$SCREEN_DIR/install/reference/bin/vvp"
CAND="$SCREEN_DIR/install/candidate/bin/vvp"
IVERILOG="$SCREEN_DIR/install/reference/bin/iverilog"
IVERILOG_VPI="$SCREEN_DIR/install/reference/bin/iverilog-vpi"
UVM_DPI=$(find "$SCREEN_DIR/install/reference" -type f -name uvm_dpi.vpi -print -quit)
RESULTS="$RUN_DIR/results"

mkdir -p "$RUN_DIR/logs" "$RUN_DIR/runner" "$RESULTS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

BASE=374b037e7c8fba7097e0b86b05be7956ca6b5487
test -x "$REF" && test -x "$CAND" && test -x "$IVERILOG" && test -x "$IVERILOG_VPI"
test -n "$UVM_DPI" && test -s "$UVM_DPI"
test -f "$SOURCE/benchmarks/sim-hotspots/run.sh"
test -f "$RUN_DIR/runner/run_json_warmup_r4.py"
printf 'measurement_base=%s\n' "$BASE" > "$RUN_DIR/measurement-base.txt"
{
  hostname
  uname -a
  printf 'measurement_base=%s\n' "$BASE"
  "$REF" -V | head -n 1
  "$CAND" -V | head -n 1
  sha256sum "$REF" "$CAND" "$IVERILOG" "$IVERILOG_VPI" "$UVM_DPI"
  sha256sum "$RUN_DIR/runner/run_json_warmup_r4.py"
} > "$RUN_DIR/environment.txt"

PATH="$(dirname "$IVERILOG"):$PATH" \
A5_SIM_HOTSPOTS_DIR="$SOURCE/benchmarks/sim-hotspots" \
IVERILOG="$IVERILOG" IVERILOG_VPI="$IVERILOG_VPI" UVM_DPI="$UVM_DPI" \
  python3 "$RUN_DIR/runner/run_json_warmup_r4.py" "$REF" "$CAND" 3 \
  > "$RESULTS/wall-3.json"
(cd "$RESULTS" && sha256sum wall-3.json > SHA256SUMS)
