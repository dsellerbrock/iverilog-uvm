#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-t1-cal-r3
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-t1-hull-cache-20261021-caliptra-r3
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-t1-hull-cache-20261021-caliptra-r3/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-t1-hull-cache-20261021-caliptra-r3
PREV=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-t1-hull-cache-20261021-corpus-r1
BASE=10f3a0a2509d0852c2556cb6622fb0025121fb2d
CANDIDATE=2a2e71b3a04888dc6a8c848be8f5b20a6be8bdd7
CALIPTRA_ROOT=/home/dsell/toolchains/iverilog-c339
RTL=$CALIPTRA_ROOT/firmware/caliptra-rtl
DEPS=$CALIPTRA_ROOT/deps
OPENSSL=$CALIPTRA_ROOT/openssl
GCC_DIR=$CALIPTRA_ROOT/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
JTAG_VPI=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf/caliptra-jtagdpi/jtagdpi.vpi
INPUT=$PREV/input
START=100
END=2100
CPU=$(awk '/Cpus_allowed_list:/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)

mkdir -p "$ROOT"/{logs,results,caliptra/logs}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(cat "$PREV/results/measurement-base.txt")" = "$BASE"
test "$(cat "$PREV/results/candidate-commit.txt")" = "$CANDIDATE"
export PATH="$OPENSSL/bin:$DEPS/bin:$GCC_DIR:/usr/bin:/bin"
test -r "$OPENSSL/lib/libcrypto.so"
test "$(readlink -f "$(command -v openssl)")" = "$(readlink -f "$OPENSSL/bin/openssl")"
test "$(git -C "$RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" = b77e3d899e828d626cfc2a0d26a6b5704cc121e0
test -d "$QD"
test -x "$PREV/install/reference/bin/vvp"
test -x "$PREV/install/candidate/bin/vvp"

{
    printf 'measurement_base=%s\ncandidate=%s\nwindow=%s..%s\ncpu=%s\n' "$BASE" "$CANDIDATE" "$START" "$END" "$CPU"
    printf 'caliptra_rtl=%s\nqd_bfm=%s\nopenssl=%s\n' "$(git -C "$RTL" rev-parse HEAD)" "$(git -C "$QD" rev-parse HEAD)" "$(readlink -f "$(command -v openssl)")"
    sha256sum "$PREV/install/reference/bin/vvp" "$PREV/install/candidate/bin/vvp"
} > "$ROOT/results/provenance.txt"

RUNNER=$INPUT/caliptra/run_caliptra_top_profile.py
for side in reference candidate; do
    INSTALL=$PREV/install/$side
    window=$ROOT/caliptra/window-$side
    mkdir -p "$window"
    (cd "$window" && "$INSTALL/bin/iverilog-vpi" "$INPUT/caliptra/mcycle-window-vpi.c") \
        > "$ROOT/logs/caliptra-window-$side.log" 2>&1
    test -s "$window/mcycle-window-vpi.vpi"
done

for case_name in smoke_test_dma_aes_gcm_short_1_dword smoke_test_sha256 cptra_ss_test_rom; do
    for side in reference candidate; do
        INSTALL=$PREV/install/$side
        export PATH="$INSTALL/bin:$OPENSSL/bin:$DEPS/bin:$GCC_DIR:/usr/bin:/bin"
        export LD_LIBRARY_PATH="$INSTALL/lib:$DEPS/lib:$OPENSSL/lib"
        export CALIPTRA_BFM_REPO=$QD CALIPTRA_MBEDTLS_ROOT=$DEPS CALIPTRA_RTL=$RTL
        export CALIPTRA_GCC_PREFIX=$GCC_DIR/riscv-none-elf- CALIPTRA_JTAGDPI_VPI=$JTAG_VPI
        export CALIPTRA_BFM_PROFILE=$RTL/src/integration/config/caliptra_top_tb.vf
        export CALIPTRA_PRIM_ROOT=$RTL/src/caliptra_prim_generic
        export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
        export IVERILOG_BIN=$INSTALL/bin/iverilog IVERILOG_VPI_BIN=$INSTALL/bin/iverilog-vpi
        export IVERILOG_SOURCE_ROOT=$PREV/source/$side UVM_DPI=$INSTALL/lib/ivl/uvm_dpi.vpi
        export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$ROOT/caliptra/window-$side/mcycle-window-vpi.vpi
        export CALIPTRA_MCYCLE_WINDOW_START=$START CALIPTRA_MCYCLE_WINDOW_END=$END
        export A5_FIXED_ECC_SOURCE=$INPUT/caliptra/ecc_secp384r1-deterministic.c
        export VVP_BIN=$INSTALL/bin/vvp IVL_PERF_STATS=1 LC_ALL=C
        out=$ROOT/caliptra/out/$side/$case_name
        evidence=$ROOT/caliptra/logs/$case_name-$side
        mkdir -p "$evidence"
        set +e
        /usr/bin/time -v -o "$evidence/resource.txt" \
            timeout --signal=INT --kill-after=60s 1800s taskset -c "$CPU" \
            "$DEPS/bin/python3.12" "$RUNNER" --case "$case_name" \
            --case-yaml "$case_name/$case_name.yml" --output "$out" \
            > "$evidence/runner.log" 2>&1
        rc=$?
        set -e
        if [[ $rc -ne 1 ]]; then
            cat "$evidence/runner.log"
            exit 1
        fi
        sim_log=$out/$case_name/sim.log
        grep -Eq "^MCYCLE_WINDOW start=$START end=$END cycles=$((END-START)) elapsed_ns=[1-9][0-9]*$" "$sim_log"
        cp "$sim_log" "$evidence/sim.log"
        (cd "$out" && find . -type f -name '*.hex' -print0 | sort -z | xargs -0 -r sha256sum) > "$evidence/generated-hex.sha256"
    done
done

python3 - "$ROOT" <<'PY'
import hashlib, json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
hist = {}
for case in ("smoke_test_dma_aes_gcm_short_1_dword", "smoke_test_sha256", "cptra_ss_test_rom"):
    hist[case] = {}
    for side in ("reference", "candidate"):
        evidence = root / "caliptra/logs" / f"{case}-{side}"
        raw = (evidence / "sim.log").read_bytes()
        matches = re.findall(rb"^MCYCLE_WINDOW start=100 end=2100 cycles=2000 elapsed_ns=([1-9][0-9]*)$", raw, re.M)
        stats = re.findall(rb"^VVP_PERF_STATS (\{.*\})$", raw, re.M)
        if len(matches) != 1 or len(stats) != 1:
            raise SystemExit(f"{case}/{side}: missing unique cycle or performance record")
        report = json.loads(stats[0])
        tiers = report.get("randomize_tiers")
        if not isinstance(tiers, dict):
            raise SystemExit(f"{case}/{side}: missing randomization tier counts")
        elapsed_ns = int(matches[0])
        normalized = re.sub(rb"(?m)^VVP_PERF_STATS \{.*\}\n?", b"", raw)
        (evidence / "functional.log").write_bytes(normalized)
        hist[case][side] = {
            "cycles": 2000,
            "elapsed_ns": elapsed_ns,
            "cycles_per_second": 2000 * 1_000_000_000 / elapsed_ns,
            "randomize_tiers": tiers,
            "randomize_calls": sum(tiers.values()),
            "functional_sha256": hashlib.sha256(normalized).hexdigest(),
            "generated_hex_sha256": hashlib.sha256((evidence / "generated-hex.sha256").read_bytes()).hexdigest(),
        }
    if (root / "caliptra/logs" / f"{case}-reference/functional.log").read_bytes() != (root / "caliptra/logs" / f"{case}-candidate/functional.log").read_bytes():
        raise SystemExit(f"{case}: normalized functional logs differ")
    if (root / "caliptra/logs" / f"{case}-reference/generated-hex.sha256").read_bytes() != (root / "caliptra/logs" / f"{case}-candidate/generated-hex.sha256").read_bytes():
        raise SystemExit(f"{case}: generated firmware images differ")

(root / "results/caliptra-tier-hist.json").write_text(json.dumps(hist, indent=2, sort_keys=True) + "\n")
with (root / "results/caliptra-summary.tsv").open("w") as stream:
    stream.write("test\treference_cycles_s\tcandidate_cycles_s\treference_calls\tcandidate_calls\tfunctional_identical\timages_identical\n")
    for case, sides in hist.items():
        ref, cand = sides["reference"], sides["candidate"]
        stream.write(f"{case}\t{ref['cycles_per_second']:.6f}\t{cand['cycles_per_second']:.6f}\t{ref['randomize_calls']}\t{cand['randomize_calls']}\tyes\tyes\n")
for directory in (root / "results", root / "caliptra/logs"):
    files = sorted(p for p in directory.rglob("*") if p.is_file() and p.name != "SHA256SUMS")
    with (directory / "SHA256SUMS").open("w") as stream:
        for path in files:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            stream.write(f"{digest}  {path.relative_to(directory)}\n")
PY
