#!/usr/bin/env bash
#SBATCH --job-name=a5-caliptra-throughput-r1
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=5G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-top-throughput-r1-20261016/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-top-throughput-r1-20261016/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-top-throughput-r1-20261016
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
C339=/home/dsell/toolchains/iverilog-c339
OLD_MAIN=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf
RTL=$C339/firmware/caliptra-rtl
ENV=$C339/deps
OPENSSL=$C339/openssl
GCC_DIR=$C339/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
GCC=$GCC_DIR/riscv-none-elf-
JTAG_VPI=$OLD_MAIN/caliptra-jtagdpi/jtagdpi.vpi
RUNNER=$ROOT/runner/run_caliptra_top_profile.py
WINDOW_START=100
WINDOW_END=2100

mkdir -p "$ROOT"/{build,install,logs,output,pycache,results,runs,source,submit,window}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(cat "$ROOT/input/source-base.commit")" = f9f8e0a79f230f38da6cbb4445994ad1075ad531
test "$(cat "$ROOT/input/source-main.commit")" = 7f508a8a3ab4f1a230d65abfa2543a12ca2f40a9
test "$(cat "$QD/qd-bfm.commit")" = d1529c922da402943148a0fb22648f347e30eed9
test "$(git -C "$RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" = b77e3d899e828d626cfc2a0d26a6b5704cc121e0
test -z "$(git -C "$RTL" status --porcelain --untracked-files=all)"
test -z "$(git -C "$RTL/submodules/adams-bridge" status --porcelain --untracked-files=all)"
test -x "$ENV/bin/python3.12"
test -x "$GCC_DIR/riscv-none-elf-gcc"
test -f "$JTAG_VPI"
for case_name in smoke_test_dma_aes_gcm_short_1_dword smoke_test_sha256 cptra_ss_test_rom; do
    test -f "$RTL/src/integration/test_suites/$case_name/$case_name.yml"
done

printf 'host=%s\nqd_bfm=%s\ncaliptra_rtl=%s\nrtl_adams_bridge=%s\nbase=%s\nmain=%s\nwindow=%s:%s\n' \
    "$(hostname)" "$(cat "$QD/qd-bfm.commit")" "$(git -C "$RTL" rev-parse HEAD)" \
    "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" \
    "$(cat "$ROOT/input/source-base.commit")" "$(cat "$ROOT/input/source-main.commit")" \
    "$WINDOW_START" "$WINDOW_END" > "$ROOT/results/provenance.txt"
sha256sum "$ROOT/input/"* "$ROOT/runner/run_caliptra_top_profile.py" \
    "$JTAG_VPI" > "$ROOT/results/input-sha256.txt"

build_one() {
    variant=$1
    revision=$(cat "$ROOT/input/source-$variant.commit")
    source=$ROOT/source/$variant
    install=$ROOT/install/$variant
    mkdir -p "$source" "$install"
    tar -xzf "$ROOT/input/source-$variant.tar.gz" -C "$source"
    mkdir -p "$source/uvm-core"
    tar -xzf "$ROOT/input/uvm-core.tar.gz" -C "$source/uvm-core"
    printf '%s\n' "$revision" > "$source/source.commit"
    (
        cd "$source"
        sh autoconf.sh
        ./configure --prefix="$install" --enable-libveriuser
        /usr/bin/time -v -o "$ROOT/results/build-$variant-resource.txt" timeout --signal=TERM --kill-after=30s 3600s make -j2
        timeout --signal=TERM --kill-after=30s 1800s make install
        timeout --signal=TERM --kill-after=30s 1800s make installuvm
    ) > "$ROOT/logs/build-$variant.log" 2>&1
    "$install/bin/iverilog" -V > "$ROOT/results/iverilog-$variant.txt" 2>&1
    "$install/bin/vvp" -V > "$ROOT/results/vvp-$variant.txt" 2>&1
    sha256sum "$install/bin/iverilog" "$install/bin/vvp" \
        "$install/bin/iverilog-vpi" > "$ROOT/results/binaries-$variant.sha256"
    printf 'source=%s\n' "$revision" > "$ROOT/results/source-$variant.txt"
    "$install/bin/iverilog-vpi" "$ROOT/input/mcycle-window-vpi.c" \
        > "$ROOT/logs/plugin-$variant.log" 2>&1
    test -s mcycle-window-vpi.vpi
    mv mcycle-window-vpi.vpi "$ROOT/window/$variant.vpi"
    sha256sum "$ROOT/window/$variant.vpi" >> "$ROOT/results/binaries-$variant.sha256"
}

build_one base
build_one main
python3.12 -m py_compile "$RUNNER"

CPU=$(awk '/Cpus_allowed_list/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'cpu=%s\ncpus_per_task=2\nmemory=5G\nwindow=%s:%s\n' \
    "$CPU" "$WINDOW_START" "$WINDOW_END" > "$ROOT/results/environment.txt"
printf 'repeat\tcase\tvariant\tcpu\trunner_exit\n' > "$ROOT/results/events.tsv"

run_one() {
    variant=$1
    case_name=$2
    repeat=$3
    label=$case_name-r$repeat-$variant
    install=$ROOT/install/$variant
    source=$ROOT/source/$variant
    output=$ROOT/output/$label
    evidence=$ROOT/runs/$label
    mkdir -p "$evidence" "$ROOT/pycache/$variant"
    test ! -e "$output"

    export PATH="$install/bin:$ENV/bin:$GCC_DIR:$OPENSSL/bin:/usr/bin:/bin"
    export LD_LIBRARY_PATH="$install/lib:$ENV/lib:$OPENSSL/lib"
    export CALIPTRA_BFM_REPO=$QD
    export CALIPTRA_MBEDTLS_ROOT=$ENV
    export CALIPTRA_RTL=$RTL
    export CALIPTRA_GCC_PREFIX=$GCC
    export CALIPTRA_JTAGDPI_VPI=$JTAG_VPI
    export CALIPTRA_BFM_PROFILE=$RTL/src/integration/config/caliptra_top_tb.vf
    export CALIPTRA_PRIM_ROOT=$RTL/src/caliptra_prim_generic
    export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
    export IVERILOG_BIN=$install/bin/iverilog
    export VVP_BIN=$install/bin/vvp
    export IVERILOG_VPI_BIN=$install/bin/iverilog-vpi
    export IVERILOG_SOURCE_ROOT=$source
    export PYTHONPYCACHEPREFIX=$ROOT/pycache/$variant
    export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$ROOT/window/$variant.vpi
    export CALIPTRA_MCYCLE_WINDOW_START=$WINDOW_START
    export CALIPTRA_MCYCLE_WINDOW_END=$WINDOW_END
    unset A5_PERF_DATA || true

    set +e
    /usr/bin/time -v -o "$evidence/resource.txt" \
        timeout --signal=INT --kill-after=60s 1800s taskset -c "$CPU" \
        "$ENV/bin/python3.12" "$RUNNER" \
        --case "$case_name" --case-yaml "$case_name/$case_name.yml" --output "$output" \
        > "$evidence/runner.log" 2>&1
    runner_exit=$?
    set -e
    printf '%s\t%s\t%s\t%s\t%s\n' "$repeat" "$case_name" "$variant" "$CPU" "$runner_exit" \
        >> "$ROOT/results/events.tsv"

    sim_log=$output/$case_name/sim.log
    grep '^MCYCLE_WINDOW ' "$sim_log" > "$evidence/window.txt"
    "$ENV/bin/python3.12" - "$evidence/window.txt" "$WINDOW_START" "$WINDOW_END" <<'PY'
import re, sys
text = open(sys.argv[1]).read().strip()
match = re.fullmatch(r"MCYCLE_WINDOW start=(\d+) end=(\d+) cycles=(\d+) elapsed_ns=(\d+)", text)
assert match, text
start, end, cycles, elapsed_ns = map(int, match.groups())
assert cycles >= int(sys.argv[3]) - int(sys.argv[2]) >= 2000
assert elapsed_ns > 0
PY
    "$ENV/bin/python3.12" - "$output" > "$evidence/generated-hex.tsv" <<'PY'
import hashlib, pathlib, sys
root = pathlib.Path(sys.argv[1])
for path in sorted(root.rglob("*.hex")):
    print(hashlib.sha256(path.read_bytes()).hexdigest(), path.relative_to(root), sep="\t")
PY
    gzip -c "$sim_log" > "$evidence/sim.log.gz"
    gzip -c "$evidence/runner.log" > "$evidence/runner.log.gz"
    cp "$output/result.json" "$evidence/result.json"
    grep 'Maximum resident set size' "$evidence/resource.txt" > "$evidence/peak-rss.txt"
    rm -rf "$output"
}

for repeat in 1 2 3; do
    for case_name in smoke_test_dma_aes_gcm_short_1_dword smoke_test_sha256 cptra_ss_test_rom; do
        if (( repeat % 2 )); then
            run_one base "$case_name" "$repeat"
            run_one main "$case_name" "$repeat"
        else
            run_one main "$case_name" "$repeat"
            run_one base "$case_name" "$repeat"
        fi
    done
done

"$ENV/bin/python3.12" "$ROOT/input/analyze.py" "$ROOT"
touch "$ROOT/results/SUCCESS"
