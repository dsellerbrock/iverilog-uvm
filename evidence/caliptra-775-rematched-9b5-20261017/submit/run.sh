#!/usr/bin/env bash
#SBATCH --job-name=a5-caliptra-775-rematch
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-775-rematched-9b5-20261017/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-775-rematched-9b5-20261017/logs/%x-%j.out

set -Eeuo pipefail

A5_RUN_ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-775-rematched-9b5-20261017
A5_TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/loadvec4-profile-374b-20261016-r2/source/iverilog-uvm
A5_GITHUB=https://github.com/dsellerbrock/iverilog-uvm.git
A5_QD=/home/dsell/toolchains/qd-bfm-8e34e0c
A5_C339=/home/dsell/toolchains/iverilog-c339
A5_RTL=$A5_C339/firmware/caliptra-rtl
A5_ENV=$A5_C339/deps
A5_OPENSSL=$A5_C339/openssl
A5_GCC_DIR=$A5_C339/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
A5_GCC=$A5_GCC_DIR/riscv-none-elf-
A5_OLD_MAIN=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf
A5_JTAG_VPI=$A5_OLD_MAIN/caliptra-jtagdpi/jtagdpi.vpi
A5_RUNNER=$A5_RUN_ROOT/input/run_caliptra_top_profile.py
A5_BASE=c014c0a7975a4b0b645ea34609c802be60a10f4a
A5_MAIN=9b5fad2afb4104caa816b257d5bccc40f01b8c66
A5_START=100
A5_END=600

mkdir -p "$A5_RUN_ROOT"/{source,install,logs,input,output,pycache,results,runs,window,submit}
finish() {
    A5_RC=$?
    trap - EXIT
    printf '%s\n' "$A5_RC" > "$A5_RUN_ROOT/results/job-exit-code"
    touch "$A5_RUN_ROOT/results/DONE"
    exit "$A5_RC"
}
trap finish EXIT

test "$(cat "$A5_QD/qd-bfm.commit")" = 8e34e0c6d20b6f84a5a975ba6e3de7ccd9b1dc2b
test "$(git -C "$A5_RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test "$(git -C "$A5_RTL/submodules/adams-bridge" rev-parse HEAD)" = b77e3d899e828d626cfc2a0d26a6b5704cc121e0
test -z "$(git -C "$A5_RTL" status --porcelain --untracked-files=all)"
test -z "$(git -C "$A5_RTL/submodules/adams-bridge" status --porcelain --untracked-files=all)"
test -x "$A5_ENV/bin/python3.12"
test -x "$A5_GCC_DIR/riscv-none-elf-gcc"
test -f "$A5_JTAG_VPI"
test -f "$A5_RTL/src/integration/test_suites/cptra_ss_test_rom/cptra_ss_test_rom.yml"
sha256sum "$A5_RUNNER" "$A5_RUN_ROOT/input/mcycle-window-vpi.c" "$A5_RUN_ROOT/input/ecc_secp384r1-deterministic.c" > "$A5_RUN_ROOT/results/input-sha256.txt"

checkout_side() {
    A5_VARIANT=$1
    A5_REVISION=$2
    A5_SOURCE=$A5_RUN_ROOT/source/$A5_VARIANT
    git clone --shared --no-checkout "$A5_TEMPLATE" "$A5_SOURCE" > "$A5_RUN_ROOT/logs/clone-$A5_VARIANT.log" 2>&1
    git -C "$A5_SOURCE" remote add github "$A5_GITHUB"
    git -C "$A5_SOURCE" fetch github main > "$A5_RUN_ROOT/logs/fetch-$A5_VARIANT.log" 2>&1
    git -C "$A5_SOURCE" checkout --detach "$A5_REVISION" > "$A5_RUN_ROOT/logs/checkout-$A5_VARIANT.log" 2>&1
    test "$(git -C "$A5_SOURCE" rev-parse HEAD)" = "$A5_REVISION"
    git -C "$A5_SOURCE" submodule update --init --recursive --jobs 4 > "$A5_RUN_ROOT/logs/submodules-$A5_VARIANT.log" 2>&1
    test -z "$(git -C "$A5_SOURCE" status --porcelain --untracked-files=all)"
    git -C "$A5_SOURCE" submodule status --recursive > "$A5_RUN_ROOT/results/submodules-$A5_VARIANT.txt"
}
checkout_side baseline "$A5_BASE"
checkout_side current "$A5_MAIN"

build_one() {
    A5_VARIANT=$1
    A5_REVISION=$2
    A5_SOURCE=$A5_RUN_ROOT/source/$A5_VARIANT
    A5_INSTALL=$A5_RUN_ROOT/install/$A5_VARIANT
    mkdir -p "$A5_INSTALL"
    (
        cd "$A5_SOURCE"
        sh autoconf.sh
        ./configure --prefix="$A5_INSTALL" --enable-libveriuser CFLAGS='-g0 -O2' CXXFLAGS='-g0 -O2'
        timeout --signal=TERM --kill-after=30s 3600s make -j4
        timeout --signal=TERM --kill-after=30s 1800s make install
        timeout --signal=TERM --kill-after=30s 1800s make installuvm
    ) > "$A5_RUN_ROOT/logs/build-$A5_VARIANT.log" 2>&1
    "$A5_INSTALL/bin/iverilog" -V > "$A5_RUN_ROOT/results/iverilog-$A5_VARIANT.txt" 2>&1
    "$A5_INSTALL/bin/vvp" -V > "$A5_RUN_ROOT/results/vvp-$A5_VARIANT.txt" 2>&1
    sha256sum "$A5_INSTALL/bin/iverilog" "$A5_INSTALL/bin/vvp" "$A5_INSTALL/bin/iverilog-vpi" > "$A5_RUN_ROOT/results/binaries-$A5_VARIANT.sha256"
    printf '%s\n' "$A5_REVISION" > "$A5_RUN_ROOT/results/source-$A5_VARIANT.txt"
    (
        cd "$A5_RUN_ROOT/window"
        "$A5_INSTALL/bin/iverilog-vpi" "$A5_RUN_ROOT/input/mcycle-window-vpi.c"
        test -s mcycle-window-vpi.vpi
        mv mcycle-window-vpi.vpi "$A5_VARIANT.vpi"
    ) > "$A5_RUN_ROOT/logs/plugin-$A5_VARIANT.log" 2>&1
    sha256sum "$A5_RUN_ROOT/window/$A5_VARIANT.vpi" >> "$A5_RUN_ROOT/results/binaries-$A5_VARIANT.sha256"
}
build_one baseline "$A5_BASE"
build_one current "$A5_MAIN"
"$A5_ENV/bin/python3.12" -m py_compile "$A5_RUNNER"

A5_CPU=$(awk '/Cpus_allowed_list/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'host=%s\ncpu=%s\ncpus_per_task=4\nmemory=8G\nwindow=%s:%s\nbaseline=%s\ncurrent=%s\n' \
    "$(hostname)" "$A5_CPU" "$A5_START" "$A5_END" "$A5_BASE" "$A5_MAIN" > "$A5_RUN_ROOT/results/environment.txt"
printf 'repeat\ttest\tvariant\tcpu\trunner_exit\n' > "$A5_RUN_ROOT/results/events.tsv"

run_one() {
    A5_VARIANT=$1
    A5_REPEAT=$2
    A5_CASE=cptra_ss_test_rom
    A5_LABEL=$A5_CASE-r$A5_REPEAT-$A5_VARIANT
    A5_INSTALL=$A5_RUN_ROOT/install/$A5_VARIANT
    A5_SOURCE=$A5_RUN_ROOT/source/$A5_VARIANT
    A5_OUTPUT=$A5_RUN_ROOT/output/$A5_LABEL
    A5_EVIDENCE=$A5_RUN_ROOT/runs/$A5_LABEL
    mkdir -p "$A5_EVIDENCE" "$A5_RUN_ROOT/pycache/$A5_VARIANT"
    test ! -e "$A5_OUTPUT"

    export PATH="$A5_INSTALL/bin:$A5_ENV/bin:$A5_GCC_DIR:$A5_OPENSSL/bin:/usr/bin:/bin"
    export LD_LIBRARY_PATH="$A5_INSTALL/lib:$A5_ENV/lib:$A5_OPENSSL/lib"
    export CALIPTRA_BFM_REPO=$A5_QD
    export CALIPTRA_MBEDTLS_ROOT=$A5_ENV
    export CALIPTRA_RTL=$A5_RTL
    export CALIPTRA_GCC_PREFIX=$A5_GCC
    export CALIPTRA_JTAGDPI_VPI=$A5_JTAG_VPI
    export CALIPTRA_BFM_PROFILE=$A5_RTL/src/integration/config/caliptra_top_tb.vf
    export CALIPTRA_PRIM_ROOT=$A5_RTL/src/caliptra_prim_generic
    export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
    export IVERILOG_BIN=$A5_INSTALL/bin/iverilog
    export VVP_BIN=$A5_INSTALL/bin/vvp
    export IVERILOG_VPI_BIN=$A5_INSTALL/bin/iverilog-vpi
    export IVERILOG_SOURCE_ROOT=$A5_SOURCE
    export PYTHONPYCACHEPREFIX=$A5_RUN_ROOT/pycache/$A5_VARIANT
    export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$A5_RUN_ROOT/window/$A5_VARIANT.vpi
    export CALIPTRA_MCYCLE_WINDOW_START=$A5_START
    export CALIPTRA_MCYCLE_WINDOW_END=$A5_END
    export A5_FIXED_ECC_SOURCE=$A5_RUN_ROOT/input/ecc_secp384r1-deterministic.c
    unset A5_PERF_DATA || true

    set +e
    /usr/bin/time -v -o "$A5_EVIDENCE/resource.txt" timeout --signal=INT --kill-after=60s 1200s \
        taskset -c "$A5_CPU" "$A5_ENV/bin/python3.12" "$A5_RUNNER" \
        --case "$A5_CASE" --case-yaml "$A5_CASE/$A5_CASE.yml" --output "$A5_OUTPUT" \
        > "$A5_EVIDENCE/runner.log" 2>&1
    A5_RUNNER_EXIT=$?
    set -e
    printf '%s\t%s\t%s\t%s\t%s\n' "$A5_REPEAT" "$A5_CASE" "$A5_VARIANT" "$A5_CPU" "$A5_RUNNER_EXIT" >> "$A5_RUN_ROOT/results/events.tsv"

    A5_SIM_LOG=$A5_OUTPUT/$A5_CASE/sim.log
    grep '^MCYCLE_WINDOW ' "$A5_SIM_LOG" > "$A5_EVIDENCE/window.txt"
    "$A5_ENV/bin/python3.12" - "$A5_EVIDENCE/window.txt" "$A5_START" "$A5_END" <<'PY'
import re, sys
text = open(sys.argv[1]).read().strip()
match = re.fullmatch(r"MCYCLE_WINDOW start=(\d+) end=(\d+) cycles=(\d+) elapsed_ns=(\d+)", text)
assert match, text
start, end, cycles, elapsed_ns = map(int, match.groups())
assert (start, end, cycles) == (int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[3])-int(sys.argv[2]))
assert elapsed_ns > 0
PY
    (cd "$A5_OUTPUT" && find . -name '*.hex' -print0 | sort -z | xargs -0 sha256sum) > "$A5_EVIDENCE/generated-hex.txt"
    gzip -c "$A5_SIM_LOG" > "$A5_EVIDENCE/sim.log.gz"
    gzip -c "$A5_EVIDENCE/runner.log" > "$A5_EVIDENCE/runner.log.gz"
    cp "$A5_OUTPUT/result.json" "$A5_EVIDENCE/result.json"
    grep 'Maximum resident set size' "$A5_EVIDENCE/resource.txt" > "$A5_EVIDENCE/peak-rss.txt"
    rm -rf "$A5_OUTPUT"
}

for A5_REPEAT in 1 2 3; do
    if (( A5_REPEAT % 2 == 1 )); then
        run_one baseline "$A5_REPEAT"
        run_one current "$A5_REPEAT"
    else
        run_one current "$A5_REPEAT"
        run_one baseline "$A5_REPEAT"
    fi
done

touch "$A5_RUN_ROOT/results/SUCCESS"
