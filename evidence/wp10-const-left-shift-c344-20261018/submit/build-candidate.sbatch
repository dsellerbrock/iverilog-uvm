#!/usr/bin/env bash
#SBATCH --job-name=a5-wp10-build
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-const-left-shift-c344-20261018/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-const-left-shift-c344-20261018/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp10-const-left-shift-c344-20261018
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
SOURCE=$ROOT/source/candidate
INPUT=$ROOT/input
CANDIDATE_SHA=$(cat "$INPUT/candidate.commit")
REF_ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r3
REF_INSTALL=$REF_ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate

mkdir -p "$ROOT"/{source,install,logs,build,results}
finish() {
  rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$ROOT/results/build-exit-code"
  touch "$ROOT/results/build-DONE"
  exit "$rc"
}
trap finish EXIT

test -x "$REF_INSTALL/bin/iverilog"
test -x "$REF_INSTALL/bin/vvp"
test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"

git clone --filter=blob:none https://github.com/dsellerbrock/iverilog-uvm.git "$SOURCE" \
    > "$ROOT/logs/clone.log" 2>&1
git -C "$SOURCE" checkout --detach "$CANDIDATE_SHA" > "$ROOT/logs/checkout.log" 2>&1
git -C "$SOURCE" submodule update --init --recursive --jobs 4 \
    > "$ROOT/logs/submodules.log" 2>&1
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$CANDIDATE_SHA"
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
git -C "$SOURCE" submodule status --recursive > "$ROOT/results/submodules.txt"

(
  cd "$SOURCE"
  sh autoconf.sh
  ./configure --prefix="$CAND_INSTALL" --enable-libveriuser \
      CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
  timeout --signal=TERM --kill-after=30s 3600s make -j4
  timeout --signal=TERM --kill-after=30s 900s make install
  timeout --signal=TERM --kill-after=30s 900s make installuvm
) > "$ROOT/logs/build.log" 2>&1

SEMANTIC=$SOURCE/evidence/wp10-const-left-shift-c344-20261018/input/semantic/check-shift-semantics.sh
bash "$SEMANTIC" "$REF_INSTALL/bin/iverilog" "$REF_INSTALL/bin/vvp" \
    "$CAND_INSTALL/bin/iverilog" "$REF_INSTALL/bin/vvp" \
    > "$ROOT/results/semantic.log" 2>&1

"$REF_INSTALL/bin/iverilog" -g2012 -o "$ROOT/build/rtl_pipe.reference.vvp" \
    "$SOURCE/benchmarks/sim-hotspots/rtl_pipe.sv"
"$CAND_INSTALL/bin/iverilog" -g2012 -o "$ROOT/build/rtl_pipe.candidate.vvp" \
    "$SOURCE/benchmarks/sim-hotspots/rtl_pipe.sv"
printf 'reference part=' > "$ROOT/results/netlist-counts.txt"
grep -c '\.part' "$ROOT/build/rtl_pipe.reference.vvp" >> "$ROOT/results/netlist-counts.txt" || true
printf 'reference concat=' >> "$ROOT/results/netlist-counts.txt"
grep -c '\.concat' "$ROOT/build/rtl_pipe.reference.vvp" >> "$ROOT/results/netlist-counts.txt" || true
printf 'candidate part=' >> "$ROOT/results/netlist-counts.txt"
grep -c '\.part' "$ROOT/build/rtl_pipe.candidate.vvp" >> "$ROOT/results/netlist-counts.txt" || true
printf 'candidate concat=' >> "$ROOT/results/netlist-counts.txt"
grep -c '\.concat' "$ROOT/build/rtl_pipe.candidate.vvp" >> "$ROOT/results/netlist-counts.txt" || true

printf 'measurement_base=%s\ncandidate_commit=%s\nreference_build=%s\n' \
    "$BASE" "$CANDIDATE_SHA" "$REF_ROOT" > "$ROOT/results/provenance.txt"
sha256sum "$REF_INSTALL/bin/iverilog" "$REF_INSTALL/bin/vvp" \
    "$CAND_INSTALL/bin/iverilog" "$SOURCE/evidence/wp10-const-left-shift-c344-20261018/input/semantic/shift_semantics.sv" \
    > "$ROOT/results/provenance.sha256"
touch "$ROOT/build/BUILD_SUCCESS"
touch "$ROOT/results/build-SUCCESS"
