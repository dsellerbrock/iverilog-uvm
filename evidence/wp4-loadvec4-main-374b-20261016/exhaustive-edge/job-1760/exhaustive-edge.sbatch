#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp4-edge-test
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-edge-374b-20261016-r1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-edge-374b-20261016-r1/logs/%x-%j.out

set -euo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-edge-374b-20261016-r1
SCREEN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r2
RESULTS="$RUN_DIR/results"
INSTALL="$SCREEN_DIR/install"
TEST="$RUN_DIR/sv_vpi_wide_index.v"

mkdir -p "$RUN_DIR/logs" "$RESULTS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

cp "$RUN_DIR/incoming/sv_vpi_wide_index.v" "$TEST"
printf 'measurement_base=374b037e7c8fba7097e0b86b05be7956ca6b5487\n' \
  > "$RUN_DIR/measurement-base.txt"
sha256sum "$TEST" "$INSTALL/reference/bin/iverilog" "$INSTALL/reference/bin/vvp" \
  "$INSTALL/candidate/bin/iverilog" "$INSTALL/candidate/bin/vvp" \
  > "$RUN_DIR/binaries.sha256"

for side in reference candidate; do
  "${INSTALL}/$side/bin/iverilog" -g2012 -o "$RUN_DIR/$side.vvp" "$TEST" \
    > "$RUN_DIR/logs/$side.compile.log" 2>&1
  "${INSTALL}/$side/bin/vvp" "$RUN_DIR/$side.vvp" \
    > "$RESULTS/$side.stdout" 2> "$RESULTS/$side.stderr"
  grep -qx PASSED "$RESULTS/$side.stdout"
done
cmp "$RESULTS/reference.stdout" "$RESULTS/candidate.stdout"
cmp "$RESULTS/reference.stderr" "$RESULTS/candidate.stderr"
printf 'all four-state X/Z patterns and wide boundary cases passed\n' \
  > "$RESULTS/summary.txt"
