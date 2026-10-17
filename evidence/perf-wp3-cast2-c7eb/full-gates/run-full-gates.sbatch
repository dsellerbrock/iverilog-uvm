#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp3-gates
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-gates1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-gates1/logs/%x-%j.out

set -euo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-gates1
INPUT="$RUN_DIR/incoming"
SRC="$RUN_DIR/source"
INSTALL="$RUN_DIR/build/install"
LOGS="$RUN_DIR/logs"
RESULTS="$RUN_DIR/results"
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
UVM_CORE=78c06547a2a0a29b3dc9dcafae62b75b2ff61544
overall=0

mkdir -p "$LOGS" "$RESULTS" "$RUN_DIR/build"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

cp "$INPUT/input-manifest.txt" "$RUN_DIR/input-manifest.txt"
grep -qx "measurement_base=$BASE" "$INPUT/input-manifest.txt"
grep -qx "uvm_core=$UVM_CORE" "$INPUT/input-manifest.txt"
candidate_sha=$(sed -n 's/^candidate_source_sha256=//p' "$INPUT/input-manifest.txt")
overlay_sha=$(sed -n 's/^correctness_overlay_sha256=//p' "$INPUT/input-manifest.txt")
printf '%s  candidate-source.tar.gz\n%s  correctness-overlay.tar.gz\n' \
  "$candidate_sha" "$overlay_sha" | (cd "$INPUT" && sha256sum -c -)

mkdir -p "$SRC"
tar -xzf "$INPUT/candidate-source.tar.gz" -C "$SRC"
tar -xzf "$INPUT/correctness-overlay.tar.gz" -C "$SRC"
test -s "$SRC/ivtest/ivltests/sv_cast2_4state.v"
test -s "$SRC/ivtest/vvp_tests/sv_cast2_4state.json"
grep -q '^sv_cast2_4state[[:space:]]' "$SRC/ivtest/regress-vvp.list"

run_bounded() {
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

run_bounded build-candidate 5400 bash -c '
  set -euo pipefail
  src=$1
  prefix=$2
  cd "$src"
  sh autoconf.sh
  ./configure --prefix="$prefix" --enable-libveriuser CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2"
  make -j4
  make install
  export PATH="$prefix/bin:$PATH" IVERILOG="$prefix/bin/iverilog" VVP="$prefix/bin/vvp"
  make installuvm
' _ "$SRC" "$INSTALL"

if [[ ! -x "$INSTALL/bin/iverilog" || ! -x "$INSTALL/bin/vvp" ]]; then
  overall=1
  exit 1
fi
export PATH="$INSTALL/bin:$PATH"
export IVERILOG="$INSTALL/bin/iverilog" VVP="$INSTALL/bin/vvp"
{
  hostname
  uname -a
  git -C "$SRC" rev-parse --is-inside-work-tree 2>/dev/null || true
  "$IVERILOG" -V | head -n 1
  "$VVP" -V | head -n 1
  printf 'measurement_base=%s\nuvm_core=%s\n' "$BASE" "$UVM_CORE"
} > "$RUN_DIR/environment.txt"

run_bounded tgt-fpga-install 600 make -C "$SRC/tgt-fpga" install
run_bounded ivtest-gate 14400 bash "$SRC/.github/ivtest_gate.sh"
run_bounded json-regression 14400 bash -c '
  set -euo pipefail
  cd "$1/ivtest"
  exec python3 ./vvp_reg.py
' _ "$SRC"
run_bounded uvm-real-dpi 14400 bash -c '
  set -euo pipefail
  cd "$1"
  exec bash .github/uvm_test.sh
' _ "$SRC"

exit "$overall"
