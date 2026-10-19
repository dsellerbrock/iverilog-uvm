#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-vpi-u32-gates
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-intval-u32-gates-ca559-20261018-r1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-intval-u32-gates-ca559-20261018-r1/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-intval-u32-gates-ca559-20261018-r1
BASE=ca559fd97b19bd6a56cc10f0faf8583b4077975f
TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-current-main-profile-20261017/source
SOURCE=$ROOT/source/candidate
INSTALL=$ROOT/install/candidate
REF_INSTALL=/home/dsell/toolchains/iverilog-uvm-ca559fd97b19bd6a56cc10f0faf8583b4077975f-m3-profile
INPUT=$ROOT/input
RESULTS=$ROOT/results
LOGS=$ROOT/logs
overall=0
mkdir -p "$ROOT"/{source,install,input,logs,results}
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/source.commit")" = "$BASE"
test "$(git -C "$TEMPLATE" rev-parse HEAD)" = "$BASE"
test -f "$INPUT/candidate.patch"
git clone --shared --no-checkout "$TEMPLATE" "$SOURCE" > "$LOGS/clone.log" 2>&1
git -C "$SOURCE" checkout --detach "$BASE" > "$LOGS/checkout.log" 2>&1
git -C "$SOURCE" submodule update --init --recursive --jobs 4 > "$LOGS/submodules.log" 2>&1
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
git -C "$SOURCE" apply --check "$INPUT/candidate.patch"
git -C "$SOURCE" apply "$INPUT/candidate.patch" > "$RESULTS/patch.log"
test "$(git -C "$SOURCE" status --porcelain --untracked-files=all)" = ' M vvp/vpi_priv.cc'
if (
  cd "$SOURCE"
  sh autoconf.sh
  ./configure --prefix="$INSTALL" --enable-libveriuser CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
  timeout --signal=TERM --kill-after=30s 5400s make -j4
  timeout --signal=TERM --kill-after=30s 900s make install
  timeout --signal=TERM --kill-after=30s 900s make installuvm
) > "$LOGS/build-candidate.log" 2>&1; then
  :
else
  overall=1
fi
if [[ $overall -eq 0 ]]; then
  export PATH="$INSTALL/bin:$PATH"
  export IVERILOG="$INSTALL/bin/iverilog" VVP="$INSTALL/bin/vvp"
  export IVERILOG_VPI="$INSTALL/bin/iverilog-vpi" UVM_DPI="$INSTALL/lib/ivl/uvm_dpi.vpi"
  {
    hostname
    uname -a
    printf 'measurement_base=%s\n' "$BASE"
    "$IVERILOG" -V | head -n 1
    "$VVP" -V | head -n 1
    printf '\n'
    grep -E '^(CPU\(s\)|Model name|Thread|MHz):' /proc/cpuinfo | head -n 8 || true
  } > "$ROOT/environment.txt"
  sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" "$INSTALL/bin/iverilog-vpi" \
    "$INSTALL/lib/ivl/uvm_dpi.vpi" "$INPUT/candidate.patch" > "$ROOT/binaries.sha256"
  git -C "$SOURCE" status --short > "$ROOT/source-status.txt"
  git -C "$SOURCE" submodule status --recursive > "$ROOT/submodules.txt"
  run_stage() {
    local name=$1 limit=$2 rc
    shift 2
    if /usr/bin/time -v -o "$LOGS/$name.time" \
        python3 "$SOURCE/scripts/run_with_timeout.py" "$limit" -- "$@" \
        > "$LOGS/$name.log" 2>&1; then
      rc=0
    else
      rc=$?
      overall=1
    fi
    printf '%s\t%s\n' "$name" "$rc" >> "$RESULTS/stage-status.tsv"
  }
  : > "$RESULTS/stage-status.tsv"
  run_stage vpi-intval-semantics 600 bash "$INPUT/semantic-check.sh" \
    "$REF_INSTALL" "$INSTALL" "$INPUT/semantic" "$ROOT/semantic"
  run_stage make-check 5400 make -C "$SOURCE" -j4 check
  run_stage tgt-fpga-install 600 make -C "$SOURCE/tgt-fpga" install
  run_stage ivtest-gate 14400 bash "$SOURCE/.github/ivtest_gate.sh"
  run_stage uvm-real-dpi 14400 bash -c 'set -euo pipefail; cd "$1"; exec bash .github/uvm_test.sh' _ "$SOURCE"
fi
exit "$overall"
