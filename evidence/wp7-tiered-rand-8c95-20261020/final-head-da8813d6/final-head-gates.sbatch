#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-finalhead
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=08:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-final-head-da8813d6-20261020
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-final-head-da8813d6-20261020/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-final-head-da8813d6-20261020
SHA=da8813d6c68d6c73708cd4751ecdc67821dc1964
BRANCH=agent/a5-perf-wp7-tiered-rand-8c95
GITHUB=https://github.com/dsellerbrock/iverilog-uvm.git
SOURCE=$ROOT/source
INSTALL=$ROOT/install
LOGS=$ROOT/logs/gates
RESULTS=$ROOT/results
mkdir -p "$ROOT"/{source,install,logs/gates,results}
overall=0
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    if (( rc == 0 )); then touch "$RESULTS/SUCCESS"; fi
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

git clone --no-checkout --branch "$BRANCH" --single-branch "$GITHUB" "$SOURCE" \
    > "$ROOT/logs/clone.log" 2>&1
git -C "$SOURCE" checkout --detach "$SHA" > "$ROOT/logs/checkout.log" 2>&1
git -C "$SOURCE" submodule update --init --recursive --jobs 4 \
    > "$ROOT/logs/submodules.log" 2>&1
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$SHA"
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
{
    hostname
    uname -a
    printf 'source_commit=%s\nbranch=%s\ncpus_per_task=4\n' "$SHA" "$BRANCH"
    git -C "$SOURCE" submodule status --recursive
    git -C "$SOURCE" status --short --untracked-files=all
} > "$ROOT/provenance.txt"

(
    cd "$SOURCE"
    sh autoconf.sh
    ./configure --prefix="$INSTALL" --enable-libveriuser \
        CFLAGS='-g -O2 -fno-omit-frame-pointer' \
        CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
    timeout --signal=TERM --kill-after=30s 3600s make -j4
    timeout --signal=TERM --kill-after=30s 900s make install
    timeout --signal=TERM --kill-after=30s 900s make installuvm
) > "$ROOT/logs/build-install.log" 2>&1
export PATH="$INSTALL/bin:$PATH"
export IVERILOG="$INSTALL/bin/iverilog" VVP="$INSTALL/bin/vvp"
export IVERILOG_VPI="$INSTALL/bin/iverilog-vpi"
export UVM_DPI="$INSTALL/lib/ivl/uvm_dpi.vpi"
sha256sum "$IVERILOG" "$VVP" "$IVERILOG_VPI" "$UVM_DPI" > "$ROOT/binaries.sha256"

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
run_stage make-check 5400 make -C "$SOURCE" -j4 check
run_stage tgt-fpga-install 600 make -C "$SOURCE/tgt-fpga" install
run_stage ivtest-gate 14400 bash "$SOURCE/.github/ivtest_gate.sh"
run_stage uvm-real-dpi 14400 bash -c 'set -euo pipefail; cd "$1"; exec bash .github/uvm_test.sh' _ "$SOURCE"
(cd "$ROOT" && find logs/gates results -type f ! -name SHA256SUMS -print0 \
    | sort -z | xargs -0 sha256sum) > "$RESULTS/SHA256SUMS"
exit "$overall"
