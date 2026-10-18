#!/usr/bin/env bash
#SBATCH --job-name=a5-wp5-build-ca559
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp5-context-unlink-ca559-20261017/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp5-context-unlink-ca559-20261017/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp5-context-unlink-ca559-20261017
BASE=ca559fd97b19bd6a56cc10f0faf8583b4077975f
TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-current-main-profile-20261017/source
REF_INSTALL=/home/dsell/toolchains/iverilog-uvm-ca559fd97b19bd6a56cc10f0faf8583b4077975f-m3-profile
SOURCE=$ROOT/source/candidate
INSTALL=$ROOT/install/candidate
INPUT=$ROOT/input
RESULTS=$ROOT/build-screen
mkdir -p "$ROOT"/{source,install,logs,submit,input} "$RESULTS"
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
test -x "$REF_INSTALL/bin/vvp" && test -x "$REF_INSTALL/bin/iverilog"
test -f "$INPUT/candidate.patch" && test -f "$INPUT/run_json_callgrind.py"
git clone --shared --no-checkout "$TEMPLATE" "$SOURCE" > "$ROOT/logs/clone.log" 2>&1
git -C "$SOURCE" checkout --detach "$BASE" > "$ROOT/logs/checkout.log" 2>&1
git -C "$SOURCE" submodule update --init --recursive --jobs 4 > "$ROOT/logs/submodules.log" 2>&1
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
git -C "$SOURCE" apply --check "$INPUT/candidate.patch"
git -C "$SOURCE" apply "$INPUT/candidate.patch" > "$RESULTS/patch.log"
test "$(git -C "$SOURCE" status --porcelain --untracked-files=all)" = ' M vvp/vthread.cc'
(
    cd "$SOURCE"
    sh autoconf.sh
    ./configure --prefix="$INSTALL" --enable-libveriuser CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
    timeout --signal=TERM --kill-after=30s 5400s make -j4
    timeout --signal=TERM --kill-after=30s 900s make install
    timeout --signal=TERM --kill-after=30s 900s make installuvm
) > "$ROOT/logs/build-candidate.log" 2>&1
"$INSTALL/bin/vvp" -V > "$RESULTS/candidate-vvp-version.txt" 2>&1
"$REF_INSTALL/bin/vvp" -V > "$RESULTS/reference-vvp-version.txt" 2>&1
sha256sum "$INPUT/candidate.patch" "$REF_INSTALL/bin/vvp" "$REF_INSTALL/bin/iverilog" \
  "$INSTALL/bin/vvp" "$INSTALL/bin/iverilog" "$INSTALL/bin/iverilog-vpi" \
  "$INSTALL/lib/ivl/uvm_dpi.vpi" > "$RESULTS/binary-source.sha256"
git -C "$SOURCE" diff --check > "$RESULTS/diff-check.txt"
git -C "$SOURCE" status --short > "$RESULTS/source-status.txt"
printf 'base=%s\nreference_install=%s\ncandidate_source=%s\ncandidate_install=%s\n' \
  "$BASE" "$REF_INSTALL" "$SOURCE" "$INSTALL" > "$RESULTS/provenance.txt"
touch "$RESULTS/BUILD_SUCCESS"
