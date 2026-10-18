#!/usr/bin/env bash
#SBATCH --job-name=a5-m3-corpus-profile
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-corpus-current-main-profile-20261017-r1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-corpus-current-main-profile-20261017-r1/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-corpus-current-main-profile-20261017-r1
COMMIT=ca559fd97b19bd6a56cc10f0faf8583b4077975f
SOURCE=$ROOT/source
TOOLCHAIN=/home/dsell/toolchains/iverilog-uvm-ca559fd97b19bd6a56cc10f0faf8583b4077975f-m3-profile
mkdir -p "$ROOT"/{logs,results,corpus}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

test "$COMMIT" = "$(cat "$ROOT/input/source.commit")"
test ! -e "$TOOLCHAIN"
git clone --filter=blob:none --no-checkout https://github.com/dsellerbrock/iverilog-uvm.git "$SOURCE" \
    > "$ROOT/logs/clone.log" 2>&1
git -C "$SOURCE" checkout --detach "$COMMIT" > "$ROOT/logs/checkout.log" 2>&1
git -C "$SOURCE" submodule update --init --recursive --jobs 4 > "$ROOT/logs/submodules.log" 2>&1
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$COMMIT"
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
git -C "$SOURCE" submodule status --recursive > "$ROOT/results/submodules.txt"

mkdir -p "$TOOLCHAIN"
(
    cd "$SOURCE"
    sh autoconf.sh
    ./configure --prefix="$TOOLCHAIN" --enable-libveriuser \
        CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
    timeout --signal=TERM --kill-after=30s 3600s make -j4
    timeout --signal=TERM --kill-after=30s 900s make install
    timeout --signal=TERM --kill-after=30s 900s make installuvm
) > "$ROOT/logs/build.log" 2>&1
chmod -R a-w "$TOOLCHAIN"

export PATH="$TOOLCHAIN/bin:/usr/bin:/bin"
export LD_LIBRARY_PATH="$TOOLCHAIN/lib"
export IVERILOG="$TOOLCHAIN/bin/iverilog"
export IVERILOG_VPI="$TOOLCHAIN/bin/iverilog-vpi"
export VVP_BIN="$TOOLCHAIN/bin/vvp"
export UVM_DPI="$TOOLCHAIN/lib/ivl/uvm_dpi.vpi"
export LC_ALL=C
printf 'source=%s\ncommit=%s\ntoolchain=%s\nperf=%s\nhost=%s\n' \
    "$SOURCE" "$COMMIT" "$TOOLCHAIN" "$(perf --version)" "$(hostname)" \
    > "$ROOT/results/provenance.txt"
grep -m1 'model name' /proc/cpuinfo >> "$ROOT/results/provenance.txt"

python3 "$ROOT/input/profile_corpus.py" "$SOURCE" "$ROOT/corpus" \
    > "$ROOT/logs/corpus-profile.log" 2>&1
find "$ROOT/results" "$ROOT/corpus" -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum \
    > "$ROOT/results/SHA256SUMS"
tar -czf "$ROOT/profile-bundle.tgz" -C "$ROOT" results corpus logs/corpus-profile.log
touch "$ROOT/results/SUCCESS"
