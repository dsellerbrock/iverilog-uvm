#!/usr/bin/env bash
#SBATCH --job-name=a5-loadprof-374b
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/loadvec4-profile-374b-20261016/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/loadvec4-profile-374b-20261016/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/loadvec4-profile-374b-20261016
SOURCE=$ROOT/source/iverilog-uvm
INSTALL=$ROOT/toolchain/install
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
C339=/home/dsell/toolchains/iverilog-c339
OLD_MAIN=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf
RTL=$C339/firmware/caliptra-rtl
ENV=$C339/deps
OPENSSL=$C339/openssl
GCC_DIR=$C339/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
GCC=$GCC_DIR/riscv-none-elf-
JTAG_VPI=$OLD_MAIN/caliptra-jtagdpi/jtagdpi.vpi
CASE=smoke_test_dma_aes_gcm_short_1_dword
CASE_YAML=$CASE/$CASE.yml

mkdir -p "$ROOT/logs" "$ROOT/window" "$ROOT/runner" "$ROOT/profiles/main" \
    "$ROOT/output/main" "$ROOT/results"
finish() {
    local rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(git -C "$SOURCE" rev-parse HEAD)" = 374b037e7c8fba7097e0b86b05be7956ca6b5487
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
test "$(cat "$QD/qd-bfm.commit")" = d1529c922da402943148a0fb22648f347e30eed9
test -x "$ENV/bin/python3.12" && test -x "$GCC_DIR/riscv-none-elf-gcc" && test -f "$JTAG_VPI"
test -f "$RTL/src/integration/test_suites/$CASE_YAML"

(
    cd "$SOURCE"
    sh autoconf.sh
    ./configure --prefix="$INSTALL" --enable-libveriuser
    timeout --signal=TERM --kill-after=15s 3600s make -j4
    timeout --signal=TERM --kill-after=15s 1800s make install
    timeout --signal=TERM --kill-after=15s 1800s make installuvm
) > "$ROOT/logs/build-install.log" 2>&1

"$INSTALL/bin/iverilog" -V > "$ROOT/profiles/main/iverilog-version.txt" 2>&1
"$INSTALL/bin/vvp" -V > "$ROOT/profiles/main/vvp-version.txt" 2>&1
sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" "$JTAG_VPI" \
    > "$ROOT/profiles/main/binaries.sha256"
printf 'source_sha=%s\nqd_bfm=d1529c922da402943148a0fb22648f347e30eed9\ncaliptra_rtl=49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e\nwindow=100:5000\n' \
    "$(git -C "$SOURCE" rev-parse HEAD)" > "$ROOT/profiles/main/provenance.txt"
git -C "$SOURCE" submodule status > "$ROOT/profiles/main/submodules.txt"

cp "$ROOT/input/mcycle-window-vpi.c" "$ROOT/window/"
(
    cd "$ROOT/window"
    "$INSTALL/bin/iverilog-vpi" mcycle-window-vpi.c
)
WINDOW_PLUGIN=$ROOT/window/mcycle-window-vpi.vpi
test -s "$WINDOW_PLUGIN"
mkdir -p "$ROOT/pycache/main"
export PATH="$ENV/bin:$INSTALL/bin:$GCC_DIR:$OPENSSL/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL/lib:$ENV/lib:$OPENSSL/lib"
export CALIPTRA_BFM_REPO=$QD
export CALIPTRA_MBEDTLS_ROOT=$ENV
export CALIPTRA_RTL=$RTL
export CALIPTRA_GCC_PREFIX=$GCC
export CALIPTRA_JTAGDPI_VPI=$JTAG_VPI
export CALIPTRA_BFM_PROFILE=$RTL/src/integration/config/caliptra_top_tb.vf
export CALIPTRA_PRIM_ROOT=$RTL/src/caliptra_prim_generic
export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
export IVERILOG_BIN=$INSTALL/bin/iverilog
export VVP_BIN=$INSTALL/bin/vvp
export IVERILOG_VPI_BIN=$INSTALL/bin/iverilog-vpi
export IVERILOG_SOURCE_ROOT=$SOURCE
export PYTHONPYCACHEPREFIX=$ROOT/pycache/main
export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$WINDOW_PLUGIN
export CALIPTRA_MCYCLE_WINDOW_START=100
export CALIPTRA_MCYCLE_WINDOW_END=5000
export A5_PERF_DATA=$ROOT/profiles/main/perf.data

CPU=$(awk '/Cpus_allowed_list/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'cpu=%s\n' "$CPU" > "$ROOT/profiles/main/cpu.txt"
set +e
/usr/bin/time -v -o "$ROOT/profiles/main/resource.txt" \
    timeout --signal=INT --kill-after=60s 1800s taskset -c "$CPU" \
    "$ENV/bin/python3.12" "$ROOT/runner/run_caliptra_top_profile.py" \
    --case "$CASE" --case-yaml "$CASE_YAML" --output "$ROOT/output/main" \
    > "$ROOT/logs/runner.log" 2>&1
runner_exit=$?
set -e
SIM_LOG=$ROOT/output/main/$CASE/sim.log
grep '^MCYCLE_WINDOW ' "$SIM_LOG" > "$ROOT/profiles/main/window-result.txt"
test -s "$ROOT/profiles/main/perf.data"
perf report --stdio --children --sort dso,symbol -i "$ROOT/profiles/main/perf.data" \
    > "$ROOT/profiles/main/perf-report-inclusive.txt"
perf report --stdio --no-children --sort dso,symbol -i "$ROOT/profiles/main/perf.data" \
    > "$ROOT/profiles/main/perf-report-self.txt"
perf script -i "$ROOT/profiles/main/perf.data" \
    > "$ROOT/profiles/main/perf-script.txt"
find "$ROOT/output/main" -maxdepth 2 -type f \( -name '*.hex' -o -name '*.vvp' \) \
    -exec sha256sum {} + > "$ROOT/profiles/main/generated-input-hashes.txt"
grep 'Maximum resident set size' "$ROOT/profiles/main/resource.txt" \
    > "$ROOT/profiles/main/peak-rss.txt"
printf 'window_complete=1\nrunner_exit=%s\nfull_test_pass=not_applicable_early_stop\n' \
    "$runner_exit" > "$ROOT/profiles/main/status.txt"
touch "$ROOT/results/SUCCESS"
