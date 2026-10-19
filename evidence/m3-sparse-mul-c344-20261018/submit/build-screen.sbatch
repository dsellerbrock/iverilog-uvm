#!/usr/bin/env bash
#SBATCH --job-name=a5-wp11-mul-c344-build
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp11-sparse-mul-c344-20261018-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp11-sparse-mul-c344-20261018-r1/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp11-sparse-mul-c344-20261018-r1
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
WP6_ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r3
SOURCE=$ROOT/source/candidate
INPUT=$ROOT/input
RESULTS=$ROOT/build
REF_INSTALL=$ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate
mkdir -p "$ROOT"/{source,install,logs,submit,input,semantic} "$RESULTS"
finish() {
    local rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/source.commit")" = "$BASE"
test -x "$REF_INSTALL/bin/iverilog" && test -x "$REF_INSTALL/bin/vvp"
test "$(git -C "$WP6_ROOT/source/reference" rev-parse HEAD)" = "$BASE"
test -z "$(git -C "$WP6_ROOT/source/reference" status --porcelain --untracked-files=all)"
test -f "$INPUT/candidate.patch" && test -f "$ROOT/semantic/run-sparse-mul-equivalence.sh"
git clone --no-checkout https://github.com/dsellerbrock/iverilog-uvm.git "$SOURCE" > "$ROOT/logs/clone.log" 2>&1
git -C "$SOURCE" checkout --detach "$BASE" > "$ROOT/logs/checkout.log" 2>&1
git -C "$SOURCE" submodule update --init --recursive --jobs 4 > "$ROOT/logs/submodules.log" 2>&1
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
git -C "$SOURCE" apply --check "$INPUT/candidate.patch"
git -C "$SOURCE" apply "$INPUT/candidate.patch" > "$RESULTS/patch.log"
test "$(git -C "$SOURCE" status --porcelain --untracked-files=all)" = ' M vvp/vvp_net.cc'
(
    cd "$SOURCE"
    sh autoconf.sh
    ./configure --prefix="$CAND_INSTALL" --enable-libveriuser CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
    timeout --signal=TERM --kill-after=30s 5400s make -j4
    timeout --signal=TERM --kill-after=30s 900s make install
) > "$ROOT/logs/build-candidate.log" 2>&1
sh "$ROOT/semantic/run-sparse-mul-equivalence.sh" \
    "$REF_INSTALL/bin/iverilog" "$REF_INSTALL/bin/vvp" \
    "$CAND_INSTALL/bin/iverilog" "$CAND_INSTALL/bin/vvp" > "$RESULTS/semantic-equivalence.txt"
"$CAND_INSTALL/bin/vvp" -V > "$RESULTS/candidate-vvp-version.txt" 2>&1
"$REF_INSTALL/bin/vvp" -V > "$RESULTS/reference-vvp-version.txt" 2>&1
sha256sum "$INPUT/candidate.patch" "$REF_INSTALL/bin/vvp" "$REF_INSTALL/bin/iverilog" \
    "$CAND_INSTALL/bin/vvp" "$CAND_INSTALL/bin/iverilog" > "$RESULTS/binary-source.sha256"
git -C "$SOURCE" diff --check > "$RESULTS/diff-check.txt"
git -C "$SOURCE" status --short > "$RESULTS/source-status.txt"
printf 'measurement_base=%s\nreference_source=%s\ncandidate_source=%s\n' \
    "$BASE" "$WP6_ROOT/source/reference" "$SOURCE" > "$RESULTS/provenance.txt"
touch "$RESULTS/BUILD_SUCCESS"
