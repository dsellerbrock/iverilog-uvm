#!/usr/bin/env bash
#SBATCH --job-name=a5-wp13-ab
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-two-state-ab-fb584-20261020-r2/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-two-state-ab-fb584-20261020-r2/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp13-two-state-ab-fb584-20261020-r2
TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/m3-current-main-profile-cc25756-20261020/source
GITHUB=https://github.com/dsellerbrock/iverilog-uvm.git
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
C339=/home/dsell/toolchains/iverilog-c339
OLD_MAIN=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf
RTL=$C339/firmware/caliptra-rtl
ENV=$C339/deps
OPENSSL=$C339/openssl
GCC_DIR=$C339/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
GCC=$GCC_DIR/riscv-none-elf-
JTAG_VPI=$OLD_MAIN/caliptra-jtagdpi/jtagdpi.vpi
INPUT=$ROOT/input/caliptra
RUNNER=$INPUT/run_caliptra_top_profile.py
BASE=fb584a251dd4cc91e56a75be662ccd5ee05c64e9
PATCH_SHA=2c23a8574b3d6eeb8eaca3a6a60b2f45cc005bdc9877944997c11fee98f3f0a0
WINDOW_START=100
WINDOW_END=2100

mkdir -p "$ROOT"/{source,install,logs,output,pycache,results,runs,window,submit}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(cat "$ROOT/input/wp13-candidate.patch.sha256" | awk '{print $1}')" = "$PATCH_SHA"
test "$(git -C "$TEMPLATE" cat-file -t "$BASE")" = commit
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

printf 'host=%s\npinned_base=%s\npatch_sha256=%s\nqd_bfm=%s\ncaliptra_rtl=%s\nrtl_adams_bridge=%s\nwindow=%s:%s\n' \
    "$(hostname)" "$BASE" "$PATCH_SHA" "$(cat "$QD/qd-bfm.commit")" \
    "$(git -C "$RTL" rev-parse HEAD)" \
    "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" \
    "$WINDOW_START" "$WINDOW_END" > "$ROOT/results/provenance.txt"
find "$ROOT/input" -type f -print0 | sort -z | xargs -0 sha256sum \
    > "$ROOT/results/input-sha256.txt"
sha256sum "$JTAG_VPI" >> "$ROOT/results/input-sha256.txt"

checkout_side() {
    variant=$1
    source=$ROOT/source/$variant
    git clone --shared --no-checkout "$TEMPLATE" "$source" > "$ROOT/logs/clone-$variant.log" 2>&1
    # The shared template is a partial clone; retain its blob filter and fetch
    # missing tracked files from the canonical remote during checkout.
    git -C "$source" remote set-url origin "$GITHUB"
    git -C "$source" config remote.origin.promisor true
    git -C "$source" config remote.origin.partialclonefilter blob:none
    git -C "$source" config extensions.partialClone origin
    git -C "$source" checkout --detach "$BASE" > "$ROOT/logs/checkout-$variant.log" 2>&1
    test "$(git -C "$source" rev-parse HEAD)" = "$BASE"
    git -C "$source" submodule update --init --recursive --jobs 2 \
        > "$ROOT/logs/submodules-$variant.log" 2>&1
    if [[ $variant == candidate ]]; then
        git -C "$source" apply --check "$ROOT/input/wp13-candidate.patch"
        git -C "$source" apply "$ROOT/input/wp13-candidate.patch"
        cp "$INPUT/run_two_state_vec4_load.sh" "$source/tests/vvp_runtime/"
        cp "$INPUT/two_state_vec4_load.sv" "$source/tests/vvp_runtime/"
        chmod +x "$source/tests/vvp_runtime/run_two_state_vec4_load.sh"
        git -C "$source" diff --check
        git -C "$source" diff --stat > "$ROOT/results/candidate-diff-stat.txt"
    else
        test -z "$(git -C "$source" status --porcelain --untracked-files=all)"
    fi
    git -C "$source" submodule status --recursive > "$ROOT/results/submodules-$variant.txt"
}
checkout_side base
checkout_side candidate

build_one() {
    variant=$1
    source=$ROOT/source/$variant
    install=$ROOT/install/$variant
    mkdir -p "$install"
    (
        cd "$source"
        sh autoconf.sh
        ./configure --prefix="$install" --enable-libveriuser CFLAGS='-g0 -O2' CXXFLAGS='-g0 -O2'
        timeout --signal=TERM --kill-after=30s 3600s make -j2
        timeout --signal=TERM --kill-after=30s 1800s make install
        timeout --signal=TERM --kill-after=30s 1800s make installuvm
    ) > "$ROOT/logs/build-$variant.log" 2>&1
    "$install/bin/iverilog" -V > "$ROOT/results/iverilog-$variant.txt" 2>&1
    "$install/bin/vvp" -V > "$ROOT/results/vvp-$variant.txt" 2>&1
    sha256sum "$install/bin/iverilog" "$install/bin/vvp" \
        "$install/bin/iverilog-vpi" > "$ROOT/results/binaries-$variant.sha256"
    printf 'source=%s\n' "$BASE" > "$ROOT/results/source-$variant.txt"
    (
        cd "$ROOT/window"
        "$install/bin/iverilog-vpi" "$INPUT/mcycle-window-vpi.c"
        test -s mcycle-window-vpi.vpi
        mv mcycle-window-vpi.vpi "$variant.vpi"
    ) > "$ROOT/logs/plugin-$variant.log" 2>&1
    sha256sum "$ROOT/window/$variant.vpi" >> "$ROOT/results/binaries-$variant.sha256"
}
build_one base
build_one candidate
IVERILOG="$ROOT/install/candidate/bin/iverilog" \
VVP="$ROOT/install/candidate/bin/vvp" \
    "$ROOT/source/candidate/tests/vvp_runtime/run_two_state_vec4_load.sh" \
    > "$ROOT/results/two-state-load-test.log" 2>&1
grep -F -x 'PASS two-state vec4 load and forced X/Z fallback' \
    "$ROOT/results/two-state-load-test.log"

"$ENV/bin/python3.12" -m py_compile "$RUNNER" "$INPUT/analyze-wp13.py"
CPU=$(awk '/Cpus_allowed_list/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'cpu=%s\ncpus_per_task=2\nmemory=8G\nwindow=%s:%s\n' \
    "$CPU" "$WINDOW_START" "$WINDOW_END" > "$ROOT/results/environment.txt"
printf 'repeat\ttest\tvariant\tcpu\trunner_exit\n' > "$ROOT/results/events.tsv"

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
    export A5_FIXED_ECC_SOURCE=$INPUT/ecc_secp384r1-deterministic.c
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
assert (start, end, cycles) == (int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[3])-int(sys.argv[2]))
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
        if (( repeat == 2 )); then
            run_one candidate "$case_name" "$repeat"
            run_one base "$case_name" "$repeat"
        else
            run_one base "$case_name" "$repeat"
            run_one candidate "$case_name" "$repeat"
        fi
    done
done

"$ENV/bin/python3.12" "$INPUT/analyze-wp13.py" "$ROOT"
touch "$ROOT/results/SUCCESS"
