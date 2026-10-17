#!/usr/bin/env bash
#SBATCH --job-name=a5-wp14-cpatch
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp14-copy-patch-sha256-measure-r3-20261017
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp14-copy-patch-sha256-measure-r3-20261017/logs/%x-%j.out
set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp14-copy-patch-sha256-measure-r3-20261017
INPUT=$ROOT/input
BUILD=$ROOT/build
RESULTS=$ROOT/results
INSTALL=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-top-throughput-3way-20261016/install/candidate
RTL=/home/dsell/toolchains/iverilog-c339/firmware/caliptra-rtl/src/sha256/rtl
RTL_ROOT=/home/dsell/toolchains/iverilog-c339/firmware/caliptra-rtl
PROFILE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp14-copy-patch-sha256-20261017/results
mkdir -p "$BUILD" "$RESULTS"
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(git -C /home/dsell/slurm-runs/iverilog-uvm/a5-perf/caliptra-top-throughput-3way-20261016/source/candidate rev-parse HEAD)" = 3b620c5ea5857ba7c022a7fba058f8a31b7ac564
test "$(git -C "$RTL_ROOT" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test -x "$INSTALL/bin/vvp"
test -x "$INSTALL/bin/iverilog"
test -x "$INSTALL/bin/iverilog-vpi"
test -f "$INPUT/copy_patch_sha256.cpp"
test -f "$INPUT/tb_sha256.sv"

CPU=$(awk '/Cpus_allowed_list/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'measurement_base=631b7a869faaa05216d8749224520227b4b23d43\ncampaign_base=f9f8e0a79f230f38da6cbb4445994ad1075ad531\ncandidate=3b620c5ea5857ba7c022a7fba058f8a31b7ac564\nrtl=49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e\ncpu=%s\n' "$CPU" > "$RESULTS/provenance.txt"
uname -a >> "$RESULTS/provenance.txt"
grep -m1 'model name' /proc/cpuinfo >> "$RESULTS/provenance.txt"
g++ --version | head -n1 >> "$RESULTS/provenance.txt"
sha256sum "$INPUT/copy_patch_sha256.cpp" "$INPUT/tb_sha256.sv" > "$RESULTS/input-sha256.txt"

g++ -std=c++17 -O3 -g0 -march=native -fno-pie -fno-stack-protector \
    -fno-asynchronous-unwind-tables -fno-unwind-tables \
    -c "$INPUT/copy_patch_sha256.cpp" -o "$BUILD/copy_patch_sha256.o"
objdump -r -j .text.sha256_round_stencil "$BUILD/copy_patch_sha256.o" > "$RESULTS/stencil-relocations.txt"
if grep -Eq 'R_X86_64_' "$RESULTS/stencil-relocations.txt"; then
    echo 'stencil contains relocations; refusing unsafe copy-and-patch' >&2
    exit 1
fi
objcopy --dump-section .text.sha256_round_stencil="$BUILD/stencil.bin" "$BUILD/copy_patch_sha256.o"
g++ -no-pie "$BUILD/copy_patch_sha256.o" -o "$BUILD/copy_patch_sha256"
sha256sum "$BUILD/copy_patch_sha256" "$BUILD/stencil.bin" > "$RESULTS/stencil-sha256.txt"

"$INSTALL/bin/iverilog" -g2012 -DNBLK=800 -s tb_sha256 -o "$BUILD/sha256.vvp" \
    "$INPUT/tb_sha256.sv" \
    "$RTL/sha256_core.v" "$RTL/sha256_w_mem.v" "$RTL/sha256_k_constants.v"

run_vvp() {
    local i=$1
    /usr/bin/time -f 'wall_seconds=%e user_seconds=%U sys_seconds=%S max_rss_kb=%M' \
        -o "$RESULTS/vvp-$i.time" timeout --signal=TERM --kill-after=10s 600s \
        taskset -c "$CPU" "$INSTALL/bin/vvp" "$BUILD/sha256.vvp" \
        > "$RESULTS/vvp-$i.out"
    grep '^NBLK=' "$RESULTS/vvp-$i.out" >> "$RESULTS/vvp-digests.txt"
}
run_spike() {
    local i=$1
    /usr/bin/time -f 'wall_seconds=%e user_seconds=%U sys_seconds=%S max_rss_kb=%M' \
        -o "$RESULTS/spike-$i.time" timeout --signal=TERM --kill-after=10s 600s \
        taskset -c "$CPU" "$BUILD/copy_patch_sha256" "$BUILD/stencil.bin" \
        > "$RESULTS/spike-$i.out"
}

: > "$RESULTS/vvp-digests.txt"
for i in 1 2 3 4 5; do
    if (( i % 2 )); then run_vvp "$i"; run_spike "$i"; else run_spike "$i"; run_vvp "$i"; fi
done

if [[ $(sort -u "$RESULTS/vvp-digests.txt" | wc -l) -ne 1 ]]; then
    echo 'VVP digest changed across repeats' >&2
    exit 1
fi
VVP_DIGEST=$(head -n1 "$RESULTS/vvp-digests.txt")
SPIKE_DIGEST=$(grep -m1 '^NBLK=' "$RESULTS/spike-1.out")
if [[ "$VVP_DIGEST" != "$SPIKE_DIGEST" ]]; then
    echo "VVP/spike digest mismatch: $VVP_DIGEST != $SPIKE_DIGEST" >&2
    exit 1
fi
python3 - "$RESULTS" <<'PY' > "$RESULTS/summary.txt"
import glob, os, re, statistics, sys
root = sys.argv[1]
def timed(prefix):
    values = []
    for path in sorted(glob.glob(os.path.join(root, prefix + "-*.time"))):
        text = open(path, encoding="utf-8").read()
        match = re.search(r"wall_seconds=([0-9.]+)", text)
        if not match:
            raise SystemExit(f"missing wall time in {path}")
        values.append(float(match.group(1)))
    return values
def spread(values):
    m = statistics.median(values)
    return 100.0 * (max(values) - min(values)) / m if m else 0.0
vvp = timed("vvp")
spike_wall = timed("spike")
interp, jit, ratios = [], [], []
for i in range(1, 6):
    text = open(os.path.join(root, f"spike-{i}.out"), encoding="utf-8").read()
    def field(name):
        return float(re.search(rf"^{name}=([0-9.]+)", text, re.M).group(1))
    interp.append(field("round_interpreter_median_seconds"))
    jit.append(field("copy_patch_jit_median_seconds"))
    ratios.append(field("round_kernel_speedup"))
print(f"vvp_workload_wall_median_seconds={statistics.median(vvp):.6f}")
print(f"vvp_workload_wall_spread_percent={spread(vvp):.3f}")
print(f"spike_process_wall_median_seconds={statistics.median(spike_wall):.6f}")
print(f"spike_process_wall_spread_percent={spread(spike_wall):.3f}")
print(f"round_interpreter_median_seconds={statistics.median(interp):.6f}")
print(f"round_interpreter_repeat_spread_percent={spread(interp):.3f}")
print(f"copy_patch_jit_median_seconds={statistics.median(jit):.6f}")
print(f"copy_patch_jit_repeat_spread_percent={spread(jit):.3f}")
print(f"round_kernel_speedup_median={statistics.median(ratios):.3f}x")
print(f"round_kernel_speedup_repeat_spread_percent={spread(ratios):.3f}")
PY
touch "$RESULTS/success"
