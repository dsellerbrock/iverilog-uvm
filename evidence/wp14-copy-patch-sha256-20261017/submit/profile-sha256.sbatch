#!/usr/bin/env bash
#SBATCH --job-name=a5-wp14-sha-prof
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp14-copy-patch-sha256-20261017
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp14-copy-patch-sha256-20261017/logs/%x-%j.out
set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp14-copy-patch-sha256-20261017
THROUGHPUT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-top-throughput-3way-20261016
INSTALL=$THROUGHPUT/install/candidate
SOURCE=$THROUGHPUT/source/candidate
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
C339=/home/dsell/toolchains/iverilog-c339
RTL=$C339/firmware/caliptra-rtl
ENV=$C339/deps
OPENSSL=$C339/openssl
GCC_DIR=$C339/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
OLD_MAIN=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf
JTAG_VPI=$OLD_MAIN/caliptra-jtagdpi/jtagdpi.vpi
RUNNER=$THROUGHPUT/input/threeway/run_caliptra_top_profile.py
PLUGIN=$THROUGHPUT/window/candidate.vpi
ECC=$THROUGHPUT/input/threeway/ecc_secp384r1-deterministic.c
OUT=$ROOT/output/smoke_test_sha256
PROFILE=$ROOT/profiles/smoke_test_sha256.data
mkdir -p "$ROOT"/{logs,output,profiles,results,pycache}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT
test "$(git -C "$SOURCE" rev-parse HEAD)" = 3b620c5ea5857ba7c022a7fba058f8a31b7ac564
test -x "$INSTALL/bin/vvp"
test -f "$PLUGIN" && test -f "$ECC" && test -f "$RUNNER"
test "$(git -C "$RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
CPU=$(awk '/Cpus_allowed_list/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'candidate=3b620c5ea5857ba7c022a7fba058f8a31b7ac564\nmeasurement_base=631b7a869faaa05216d8749224520227b4b23d43\nrtl=49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e\nwindow=100:2100\ncpu=%s\n' "$CPU" > "$ROOT/results/provenance.txt"
export PATH="$INSTALL/bin:$ENV/bin:$GCC_DIR:$OPENSSL/bin:/usr/bin:/bin"
export LD_LIBRARY_PATH="$INSTALL/lib:$ENV/lib:$OPENSSL/lib"
export CALIPTRA_BFM_REPO=$QD
export CALIPTRA_MBEDTLS_ROOT=$ENV
export CALIPTRA_RTL=$RTL
export CALIPTRA_GCC_PREFIX=$GCC_DIR/riscv-none-elf-
export CALIPTRA_JTAGDPI_VPI=$JTAG_VPI
export CALIPTRA_BFM_PROFILE=$RTL/src/integration/config/caliptra_top_tb.vf
export CALIPTRA_PRIM_ROOT=$RTL/src/caliptra_prim_generic
export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
export IVERILOG_BIN=$INSTALL/bin/iverilog
export VVP_BIN=$INSTALL/bin/vvp
export IVERILOG_VPI_BIN=$INSTALL/bin/iverilog-vpi
export IVERILOG_SOURCE_ROOT=$SOURCE
export PYTHONPYCACHEPREFIX=$ROOT/pycache
export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$PLUGIN
export CALIPTRA_MCYCLE_WINDOW_START=100
export CALIPTRA_MCYCLE_WINDOW_END=2100
export A5_FIXED_ECC_SOURCE=$ECC
unset A5_PERF_DATA || true
set +e
perf record -F 99 -e cycles:u -g --call-graph dwarf -o "$PROFILE" -- \
    taskset -c "$CPU" "$ENV/bin/python3.12" "$RUNNER" \
    --case smoke_test_sha256 --case-yaml smoke_test_sha256/smoke_test_sha256.yml \
    --output "$OUT" > "$ROOT/logs/runner.log" 2>&1
rc=$?
set -e
printf 'perf_record_exit=%s\n' "$rc" > "$ROOT/results/profile-status.txt"
test -s "$PROFILE"
grep '^MCYCLE_WINDOW ' "$OUT/smoke_test_sha256/sim.log" > "$ROOT/results/window.txt"
grep 'Maximum resident set size' "$ROOT/logs/runner.log" > "$ROOT/results/peak-rss.txt" || true
perf report -i "$PROFILE" --stdio --sort symbol --percent-limit 0.5 > "$ROOT/results/perf-report.txt"
sha256sum "$INSTALL/bin/vvp" "$RUNNER" "$PLUGIN" "$ECC" "$PROFILE" > "$ROOT/results/sha256.txt"
