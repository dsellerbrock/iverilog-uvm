#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp4-full-gates
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-gates-374b-20261016-r1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-gates-374b-20261016-r1/logs/%x-%j.out

set -uo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-gates-374b-20261016-r1
SCREEN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r2
SRC="$SCREEN_DIR/source/candidate"
INSTALL="$SCREEN_DIR/install/candidate"
RESULTS="$RUN_DIR/results"
LOGS="$RUN_DIR/logs"
overall=0

mkdir -p "$RESULTS" "$LOGS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

BASE=374b037e7c8fba7097e0b86b05be7956ca6b5487
test -x "$INSTALL/bin/iverilog"
test -x "$INSTALL/bin/vvp"
test -s "$SRC/ivtest/ivltests/sv_vpi_wide_index.v"
grep -qx 'sv_vpi_wide_index vvp_tests/sv_vpi_wide_index.json' "$SRC/ivtest/regress-vvp.list"
sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" > "$RUN_DIR/binaries.sha256"
cp "$SCREEN_DIR/input/source-manifest.txt" "$RUN_DIR/source-manifest.txt"
cp "$SCREEN_DIR/build-screen/results/provenance.txt" "$RUN_DIR/screen-provenance.txt"

export PATH="$INSTALL/bin:$PATH"
export IVERILOG="$INSTALL/bin/iverilog" VVP="$INSTALL/bin/vvp"
{
  hostname
  uname -a
  printf 'measurement_base=%s\n' "$BASE"
  "$IVERILOG" -V | head -n 1
  "$VVP" -V | head -n 1
  printf '\n'
  grep -E '^(CPU\(s\)|Model name|Thread|MHz):' /proc/cpuinfo | head -n 8 || true
} > "$RUN_DIR/environment.txt"

run_stage() {
  local name=$1 limit=$2 rc
  shift 2
  if /usr/bin/time -v -o "$LOGS/$name.time" \
      python3 "$SRC/scripts/run_with_timeout.py" "$limit" -- "$@" \
      > "$LOGS/$name.log" 2>&1; then
    rc=0
  else
    rc=$?
    overall=1
  fi
  printf '%s\t%s\n' "$name" "$rc" >> "$RESULTS/stage-status.tsv"
}

: > "$RESULTS/stage-status.tsv"
run_stage make-check 5400 make -C "$SRC" -j4 check
run_stage tgt-fpga-install 600 make -C "$SRC/tgt-fpga" install
run_stage ivtest-gate 14400 bash "$SRC/.github/ivtest_gate.sh"
run_stage json-regression 14400 bash -c 'set -euo pipefail; cd "$1/ivtest"; exec python3 ./vvp_reg.py' _ "$SRC"
run_stage uvm-real-dpi 14400 bash -c 'set -euo pipefail; cd "$1"; exec bash .github/uvm_test.sh' _ "$SRC"

exit "$overall"
