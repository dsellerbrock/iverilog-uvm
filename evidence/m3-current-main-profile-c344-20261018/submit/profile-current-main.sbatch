#!/usr/bin/env bash
#SBATCH --job-name=a5-m3-main-profile
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=3
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-current-main-profile-c344-20261018
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-current-main-profile-c344-20261018/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-current-main-profile-c344-20261018
COMMIT=c344d20197a569dea8936bad95de3d185b1e78dc
SOURCE=$ROOT/source
INSTALL=$ROOT/install
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
CALIPTRA=/home/dsell/toolchains/iverilog-c339
RTL=$CALIPTRA/firmware/caliptra-rtl
ENV=$CALIPTRA/deps
OPENSSL=$CALIPTRA/openssl
GCC_DIR=$CALIPTRA/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
JTAG_VPI=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf/caliptra-jtagdpi/jtagdpi.vpi
RUNNER=$SOURCE/evidence/caliptra-top-throughput-20261016/input/threeway/run_caliptra_top_profile.py
PROFILE_INPUT=$ROOT/input/profile_corpus.py
START=100
END=2100
CPU=$(awk '/Cpus_allowed_list:/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)

mkdir -p "$ROOT"/{source,install,logs,results,caliptra/{out,logs,profiles},corpus,window,bin}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

test "$COMMIT" = "$(cat "$ROOT/input/source.commit")"
test -x "$ENV/bin/python3.12"
test -x "$GCC_DIR/riscv-none-elf-gcc"
test -f "$JTAG_VPI"
test "$(git -C "$RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" = b77e3d899e828d626cfc2a0d26a6b5704cc121e0
test -z "$(git -C "$RTL" status --porcelain --untracked-files=all)"
test -z "$(git -C "$RTL/submodules/adams-bridge" status --porcelain --untracked-files=all)"

git clone --filter=blob:none --no-checkout https://github.com/dsellerbrock/iverilog-uvm.git "$SOURCE" \
    > "$ROOT/logs/clone.log" 2>&1
git -C "$SOURCE" checkout --detach "$COMMIT" > "$ROOT/logs/checkout.log" 2>&1
git -C "$SOURCE" submodule update --init --recursive --jobs 4 > "$ROOT/logs/submodules.log" 2>&1
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$COMMIT"
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
git -C "$SOURCE" submodule status --recursive > "$ROOT/results/submodules.txt"

(
    cd "$SOURCE"
    sh autoconf.sh
    ./configure --prefix="$INSTALL" --enable-libveriuser \
        CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
    timeout --signal=TERM --kill-after=30s 3600s make -j3
    timeout --signal=TERM --kill-after=30s 900s make install
    timeout --signal=TERM --kill-after=30s 900s make installuvm
) > "$ROOT/logs/build.log" 2>&1

WINDOW_PLUGIN_SOURCE=$SOURCE/evidence/caliptra-top-throughput-20261016/input/threeway/mcycle-window-vpi.c
ECC_SOURCE=$SOURCE/evidence/caliptra-top-throughput-20261016/input/threeway/ecc_secp384r1-deterministic.c
mkdir -p "$ROOT/window"
(
    cd "$ROOT/window"
    "$INSTALL/bin/iverilog-vpi" "$WINDOW_PLUGIN_SOURCE"
) > "$ROOT/logs/window-plugin.log" 2>&1
test -s "$ROOT/window/mcycle-window-vpi.vpi"

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
export IVERILOG_VPI_BIN=$INSTALL/bin/iverilog-vpi
export IVERILOG_SOURCE_ROOT=$SOURCE
export UVM_DPI=$INSTALL/lib/ivl/uvm_dpi.vpi
export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$ROOT/window/mcycle-window-vpi.vpi
export CALIPTRA_MCYCLE_WINDOW_START=$START
export CALIPTRA_MCYCLE_WINDOW_END=$END
export A5_FIXED_ECC_SOURCE=$ECC_SOURCE
export LC_ALL=C

REAL_VVP=$INSTALL/bin/vvp
PERF_BIN=$(command -v perf)
export REAL_VVP PERF_BIN
export PROFILE_CPU=$CPU
cat > "$ROOT/bin/perf-vvp" <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${1:-} == "-V" ]]; then
    exec "$REAL_VVP" "$@"
fi
exec taskset -c "$PROFILE_CPU" "$PERF_BIN" record -F 99 -g --call-graph fp \
    -o "$M3_PERF_OUTPUT" -- "$REAL_VVP" "$@"
WRAPPER
chmod +x "$ROOT/bin/perf-vvp"
export VVP_BIN=$ROOT/bin/perf-vvp

printf 'source=%s\ncommit=%s\nwindow=%s:%s\ncpu=%s\nperf=%s\n' \
    "$SOURCE" "$COMMIT" "$START" "$END" "$CPU" "$(perf --version)" > "$ROOT/results/provenance.txt"
printf 'host=%s\n' "$(hostname)" >> "$ROOT/results/provenance.txt"
grep -m1 'model name' /proc/cpuinfo >> "$ROOT/results/provenance.txt"
printf 'case\trunner_exit\tprofile_bytes\twindow_marker\n' > "$ROOT/results/caliptra.tsv"

for case_name in smoke_test_dma_aes_gcm_short_1_dword smoke_test_sha256 cptra_ss_test_rom; do
    test -f "$RTL/src/integration/test_suites/$case_name/$case_name.yml"
    out=$ROOT/caliptra/out/$case_name
    evidence=$ROOT/caliptra/logs/$case_name
    profile=$ROOT/caliptra/profiles/$case_name.data
    mkdir -p "$evidence"
    export M3_PERF_OUTPUT=$profile
    set +e
    /usr/bin/time -v -o "$evidence/resource.txt" \
        timeout --signal=INT --kill-after=60s 1800s taskset -c "$CPU" \
        "$ENV/bin/python3.12" "$RUNNER" --case "$case_name" \
        --case-yaml "$case_name/$case_name.yml" --output "$out" \
        > "$evidence/runner.log" 2>&1
    runner_exit=$?
    set -e
    test "$runner_exit" -eq 1
    sim_log=$out/$case_name/sim.log
    marker=$(grep '^MCYCLE_WINDOW ' "$sim_log")
    grep -Eq "^MCYCLE_WINDOW start=$START end=$END cycles=$((END-START)) elapsed_ns=[1-9][0-9]*$" <<< "$marker"
    test -s "$profile"
    perf report --stdio --no-children -g -i "$profile" > "$ROOT/caliptra/profiles/$case_name.txt" 2>&1
    gzip -1 "$profile"
    cp "$out/result.json" "$evidence/result.json"
    gzip -1c "$sim_log" > "$evidence/sim.log.gz"
    gzip -1c "$evidence/runner.log" > "$evidence/runner.log.gz"
    find "$out" -type f -name '*.hex' -print0 | sort -z | xargs -0 -r sha256sum > "$evidence/generated-hex.sha256"
    bytes=$(stat -c %s "$profile.gz")
    printf '%s\t%s\t%s\t%s\n' "$case_name" "$runner_exit" "$bytes" "$marker" \
        >> "$ROOT/results/caliptra.tsv"
    rm -rf "$out"
done

export IVERILOG="$INSTALL/bin/iverilog"
export IVERILOG_VPI="$INSTALL/bin/iverilog-vpi"
export VVP_BIN="$INSTALL/bin/vvp"
python3 "$PROFILE_INPUT" "$SOURCE" "$ROOT/corpus" > "$ROOT/logs/corpus-profile.log" 2>&1

find "$ROOT/results" "$ROOT/caliptra" "$ROOT/corpus" -type f -print0 | sort -z \
    | xargs -0 sha256sum > "$ROOT/results/SHA256SUMS"
tar -czf "$ROOT/m3-current-main-profile.tgz" -C "$ROOT" results caliptra corpus logs/corpus-profile.log
touch "$ROOT/results/SUCCESS"
