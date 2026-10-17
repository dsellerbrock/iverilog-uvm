#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp3-fst-diag-r2
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-diag2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-diag2/logs/%x-%j.out

set -euo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-diag2
BUILD=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build
SOURCE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/reference/source/benchmarks/sim-hotspots/waveform.sv
RESULTS="$RUN_DIR/results"

mkdir -p "$RESULTS" "$RUN_DIR/logs"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

IVERILOG="$BUILD/reference/install/bin/iverilog"
REF_VVP="$BUILD/reference/install/bin/vvp"
CAND_VVP="$BUILD/candidate/install/bin/vvp"
"$IVERILOG" -g2012 -o "$RUN_DIR/waveform.vvp" "$SOURCE"

for side in reference candidate; do
  mkdir -p "$RESULTS/$side"
  runtime="$REF_VVP"
  [ "$side" = reference ] || runtime="$CAND_VVP"
  set +e
  (cd "$RESULTS/$side" && "$runtime" -n "$RUN_DIR/waveform.vvp" \
    +use_fst -fst -no-date > stdout.bin 2> stderr.txt)
  rc=$?
  set -e
  printf '%s\n' "$rc" > "$RESULTS/$side/exit-code"
done

cmp "$RESULTS/reference/exit-code" "$RESULTS/candidate/exit-code"
test "$(cat "$RESULTS/reference/exit-code")" -eq 0
cmp "$RESULTS/reference/stdout.bin" "$RESULTS/candidate/stdout.bin"
cmp "$RESULTS/reference/stderr.txt" "$RESULTS/candidate/stderr.txt"
diff -r --exclude=exit-code "$RESULTS/reference" "$RESULTS/candidate"

{
  printf 'measurement_base=%s\n' c7ebca768c21c251d9c165c9aff0e363768030b1
  sha256sum "$RUN_DIR/waveform.vvp" "$RESULTS/reference/stdout.bin" \
    "$RESULTS/candidate/stdout.bin"
} > "$RUN_DIR/manifest.txt"
