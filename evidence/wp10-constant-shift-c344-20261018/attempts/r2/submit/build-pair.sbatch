#!/usr/bin/env bash
#SBATCH --job-name=a5-wp10-r2-build
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-constant-shift-c344-20261018-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-constant-shift-c344-20261018-r2/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-constant-shift-c344-20261018-r2
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
CANDIDATE=wp10-constant-shift-prototype
INPUT=$ROOT/input
REF_SOURCE=$ROOT/source/reference
CAND_SOURCE=$ROOT/source/candidate
REF_INSTALL=$ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate
RESULTS=$ROOT/results
LOGS=$ROOT/logs

mkdir -p "$ROOT"/{source,install,input,results,logs}
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"
test "$(cat "$INPUT/candidate.commit")" = "$CANDIDATE"
(
  cd "$INPUT"
  sha256sum --check source-inputs.sha256
)

stage_source() {
  local dest=$1
  mkdir -p "$dest/third_party/uvm/2020.2.0" "$dest/third_party/uvm/2020.3.0" "$dest/uvm-core"
  tar -xzf "$INPUT/iverilog-uvm-c344-sourceonly.tar.gz" -C "$dest" --strip-components=1
  tar -xzf "$INPUT/uvm-2020.2.0.tar.gz" -C "$dest/third_party/uvm/2020.2.0"
  tar -xzf "$INPUT/uvm-2020.3.0.tar.gz" -C "$dest/third_party/uvm/2020.3.0"
  tar -xzf "$INPUT/uvm-core-78c0654.tar.gz" -C "$dest/uvm-core"
}
stage_source "$REF_SOURCE"
stage_source "$CAND_SOURCE"
patch --dry-run -p1 -d "$CAND_SOURCE" < "$INPUT/candidate.patch" > "$RESULTS/patch-check.log"
patch -p1 -d "$CAND_SOURCE" < "$INPUT/candidate.patch" > "$RESULTS/patch.log"

build_install() {
  local side=$1 source_dir=$ROOT/source/$1 prefix=$ROOT/install/$1
  (
    cd "$source_dir"
    sh autoconf.sh
    ./configure --prefix="$prefix" --enable-libveriuser CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
    timeout --signal=TERM --kill-after=30s 5400s make -j4
    timeout --signal=TERM --kill-after=30s 900s make install
    timeout --signal=TERM --kill-after=30s 900s make installuvm
  ) > "$LOGS/build-$side.log" 2>&1
}
build_install reference
build_install candidate

{
  hostname
  uname -a
  printf 'measurement_base=%s\ncandidate_commit=%s\n' "$BASE" "$CANDIDATE"
  cat "$INPUT/source-provenance.txt"
  sha256sum "$INPUT/candidate.patch" \
    "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" \
    "$REF_INSTALL/bin/iverilog" "$CAND_INSTALL/bin/iverilog" \
    "$REF_INSTALL/bin/iverilog-vpi" "$CAND_INSTALL/bin/iverilog-vpi" \
    "$REF_INSTALL/lib/ivl/uvm_dpi.vpi" "$CAND_INSTALL/lib/ivl/uvm_dpi.vpi"
} > "$ROOT/provenance.txt"

"$REF_INSTALL/bin/iverilog" -g2012 -o "$RESULTS/rtl_pipe.reference.vvp" "$REF_SOURCE/benchmarks/sim-hotspots/rtl_pipe.sv"
"$CAND_INSTALL/bin/iverilog" -g2012 -o "$RESULTS/rtl_pipe.candidate.vvp" "$CAND_SOURCE/benchmarks/sim-hotspots/rtl_pipe.sv"
reference=$(grep -c '\.shift/l ' "$RESULTS/rtl_pipe.reference.vvp" || true)
candidate=$(grep -c '\.shift/l ' "$RESULTS/rtl_pipe.candidate.vvp" || true)
printf 'reference_shift_functors=%s\ncandidate_shift_functors=%s\n' "$reference" "$candidate" > "$RESULTS/shift-functor-count.txt"
test "$candidate" -gt "$reference"

sha256sum "$ROOT/provenance.txt" "$RESULTS/shift-functor-count.txt" \
  "$RESULTS/rtl_pipe.reference.vvp" "$RESULTS/rtl_pipe.candidate.vvp" \
  "$INPUT/source-inputs.sha256" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/BUILD_SUCCESS"
