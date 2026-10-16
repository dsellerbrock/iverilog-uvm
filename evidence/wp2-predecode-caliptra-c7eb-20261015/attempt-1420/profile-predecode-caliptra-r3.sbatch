#!/usr/bin/env bash
#SBATCH --job-name=a5-predecode-caliptra
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
BASE_SOURCE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/reference/source
REF_INSTALL=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build/reference/install
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
RTL=/home/dsell/toolchains/iverilog-c339/firmware/caliptra-rtl
ENV=/home/dsell/toolchains/iverilog-c339/deps
OPENSSL=/home/dsell/toolchains/iverilog-c339/openssl
GCC_DIR=/home/dsell/toolchains/iverilog-c339/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
JTAG_VPI=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf/caliptra-jtagdpi/jtagdpi.vpi
TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/tools/root
INPUT=$ROOT/input
CASE=smoke_test_dma_aes_gcm_short_1_dword
CASE_YAML=$CASE/$CASE.yml
CAND_SOURCE=$ROOT/candidate/source
CAND_INSTALL=$ROOT/build/candidate/install
RUNNER=$ROOT/runner/run_caliptra_top_profile.py

mkdir -p "$ROOT/logs" "$ROOT/window" "$ROOT/profiles" "$ROOT/output" \
    "$ROOT/pycache" "$ROOT/results" "$ROOT/build" "$ROOT/candidate" "$ROOT/runner"
finish() {
    local rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

test -f "$BASE_SOURCE/Makefile.in"
test -x "$REF_INSTALL/bin/iverilog" && test -x "$REF_INSTALL/bin/vvp"
test "$(cat "$QD/qd-bfm.commit")" = d1529c922da402943148a0fb22648f347e30eed9
test "$(git -C "$RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" = b77e3d899e828d626cfc2a0d26a6b5704cc121e0
grep -qx "measurement_base=$BASE" \
    /home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/input-manifest.txt
test -x "$TOOLS/usr/bin/valgrind" && test -f "$TOOLS/usr/include/valgrind/callgrind.h"
test -f "$INPUT/ecc_secp384r1-deterministic.c"
printf 'measurement_base=%s\ncase=%s\nwindow=100:200\n' "$BASE" "$CASE" \
    > "$ROOT/results/provenance.txt"
sha256sum "$INPUT"/* >> "$ROOT/results/provenance.txt"

cp -a "$BASE_SOURCE" "$CAND_SOURCE"
patch -d "$CAND_SOURCE" -p1 < "$INPUT/wp2-predecode.patch" > "$ROOT/results/patch-v1.log"
patch -d "$CAND_SOURCE" -p1 < "$INPUT/wp2-predecode-v2.patch" > "$ROOT/results/patch-v2.log"
(
    cd "$CAND_SOURCE"
    sh autoconf.sh > "$ROOT/logs/autoconf-candidate.log" 2>&1
    ./configure --prefix="$CAND_INSTALL" --enable-libveriuser CFLAGS='-g0 -O2' CXXFLAGS='-g0 -O2' \
        > "$ROOT/logs/configure-candidate.log" 2>&1
    make -j2 > "$ROOT/logs/build-candidate.log" 2>&1
    make install > "$ROOT/logs/install-candidate.log" 2>&1
)

cp "$QD/dv/caliptra_bfm/uvm/tests/run_caliptra_top_firmware_bfm.py" "$RUNNER"
"$ENV/bin/python3.12" - "$RUNNER" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
replacements = (
    ("REPO = Path(__file__).resolve().parents[4]",
     'REPO = Path(os.environ["CALIPTRA_BFM_REPO"]).resolve()'),
    ('        "ecc_secp384r1.c": Path(rtl_root) / "src/ecc/tb/ecc_secp384r1.c",',
     '        "ecc_secp384r1.c": Path(os.environ.get("A5_FIXED_ECC_SOURCE", '
     'str(Path(rtl_root) / "src/ecc/tb/ecc_secp384r1.c"))),'),
    ('    path = Path(root).expanduser().resolve()\n\n    def git(*args):',
     '    path = Path(root).expanduser().resolve()\n    pin = path / "qd-bfm.commit"\n'
     '    if pin.is_file():\n        return {"root": str(path), "commit": pin.read_text().strip(),\n'
     '                "clean": True, "remote_tracking_refs_containing_head": []}\n'
     '    revision = os.environ.get("IVERILOG_SOURCE_REVISION")\n'
     '    if revision:\n        return {"root": str(path), "commit": revision,\n'
     '                "clean": os.environ.get("IVERILOG_SOURCE_CLEAN") == "1",\n'
     '                "remote_tracking_refs_containing_head": []}\n\n    def git(*args):'),
    ('def build_sim_command(vvp, jtagdpi, binary, plusargs, progress_plugin, stdbuf):\n'
     '    command = [stdbuf, "-oL"] if stdbuf else []\n'
     '    command.extend([vvp, "-d", jtagdpi, "-n", "-m", progress_plugin, binary, *plusargs])\n'
     '    return command',
     'def build_sim_command(vvp, jtagdpi, binary, plusargs, progress_plugin, stdbuf):\n'
     '    return [os.environ["A5_VALGRIND"], "--quiet", "--tool=callgrind", "--instr-atstart=no",\n'
     '            "--cache-sim=no", "--branch-sim=no",\n'
     '            "--callgrind-out-file=" + os.environ["A5_CALLGRIND_OUT"], "--",\n'
     '            vvp, "-d", jtagdpi, "-n", "-m", progress_plugin,\n'
     '            "-m", os.environ["CALIPTRA_MCYCLE_WINDOW_PLUGIN"], binary, *plusargs]'),
)
for old, new in replacements:
    if text.count(old) != 1:
        raise SystemExit(f"expected one runner anchor, found {text.count(old)}: {old[:80]!r}")
    text = text.replace(old, new, 1)
path.write_text(text)
PY

run_side() {
    local label=$1 install=$2 profile=$3 output=$4
    local plugin_dir=$ROOT/window/$label
    local source_root=$BASE_SOURCE source_clean=1
    if [ "$label" = candidate ]; then
        source_root=$CAND_SOURCE
        source_clean=0
    fi
    mkdir -p "$plugin_dir" "$profile" "$ROOT/pycache/$label"
    cp "$INPUT/mcycle-window-callgrind.c" "$plugin_dir/"
    export C_INCLUDE_PATH="$TOOLS/usr/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
    (cd "$plugin_dir" && "$install/bin/iverilog-vpi" mcycle-window-callgrind.c \
        > "$profile/plugin-build.log" 2>&1)
    test -s "$plugin_dir/mcycle-window-callgrind.vpi"
    export PATH="$ENV/bin:$install/bin:$GCC_DIR:$OPENSSL/bin:$PATH"
    export LD_LIBRARY_PATH="$install/lib:$ENV/lib:$OPENSSL/lib"
    export CALIPTRA_BFM_REPO=$QD
    export CALIPTRA_MBEDTLS_ROOT=$ENV
    export CALIPTRA_RTL=$RTL
    export CALIPTRA_GCC_PREFIX=$GCC_DIR/riscv-none-elf-
    export CALIPTRA_JTAGDPI_VPI=$JTAG_VPI
    export CALIPTRA_BFM_PROFILE=$RTL/src/integration/config/caliptra_top_tb.vf
    export CALIPTRA_PRIM_ROOT=$RTL/src/caliptra_prim_generic
    export CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
    export IVERILOG_BIN=$install/bin/iverilog
    export VVP_BIN=$install/bin/vvp
    export IVERILOG_VPI_BIN=$install/bin/iverilog-vpi
    export IVERILOG_SOURCE_ROOT=$source_root
    export IVERILOG_SOURCE_REVISION=$BASE
    export IVERILOG_SOURCE_CLEAN=$source_clean
    export PYTHONPYCACHEPREFIX=$ROOT/pycache/$label
    export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$plugin_dir/mcycle-window-callgrind.vpi
    export CALIPTRA_MCYCLE_WINDOW_START=100
    export CALIPTRA_MCYCLE_WINDOW_END=200
    export A5_FIXED_ECC_SOURCE=$INPUT/ecc_secp384r1-deterministic.c
    export A5_VALGRIND=$TOOLS/usr/bin/valgrind
    export A5_CALLGRIND_OUT=$profile/callgrind.out.%p
    export VALGRIND_LIB=$TOOLS/usr/libexec/valgrind
    "$install/bin/iverilog" -V > "$profile/iverilog-version.txt" 2>&1
    "$install/bin/vvp" -V > "$profile/vvp-version.txt" 2>&1
    sha256sum "$install/bin/iverilog" "$install/bin/vvp" "$install/bin/iverilog-vpi" \
        "$plugin_dir/mcycle-window-callgrind.vpi" > "$profile/binaries.sha256"
    printf 'label=%s\nmeasurement_base=%s\ncase=%s\nwindow=100:200\n' \
        "$label" "$BASE" "$CASE" > "$profile/provenance.txt"
    set +e
    /usr/bin/time -v -o "$profile/resource.txt" \
        timeout --signal=INT --kill-after=60s 3600s \
        "$ENV/bin/python3.12" "$RUNNER" --case "$CASE" --case-yaml "$CASE_YAML" --output "$output" \
        > "$ROOT/logs/$label-runner.log" 2>&1
    local runner_exit=$?
    set -e
    local sim_log=$output/$CASE/sim.log
    grep '^CALLGRIND_MCYCLE_WINDOW start=100 end=200 cycles=100$' "$sim_log" \
        > "$profile/window-result.txt"
    find "$profile" -maxdepth 1 -type f -name 'callgrind.out.*' -size +0c | sort \
        > "$profile/profile-files.txt"
    test -s "$profile/profile-files.txt"
    "$ENV/bin/python3.12" - "$profile/profile-files.txt" "$profile/instructions.txt" <<'PY'
from pathlib import Path
import re
import sys
paths = [Path(line) for line in Path(sys.argv[1]).read_text().splitlines()]
counts = []
for path in paths:
    lines = path.read_text().splitlines()
    if "desc: Trigger: Client Request: fixed mcycle window" not in lines:
        continue
    rows = [int(match.group(1)) for line in lines
            if (match := re.fullmatch(r"totals:\s+(\d+)", line))]
    if len(rows) != 1 or rows[0] <= 0:
        raise SystemExit(f"expected one positive Callgrind total in {path}, got {rows}")
    counts.append((path.name, rows[0]))
if len(counts) != 1:
    raise SystemExit(f"expected one fixed-window profile, found {counts}")
Path(sys.argv[2]).write_text(
    f"{counts[0][0]} {counts[0][1]}\nTOTAL {counts[0][1]}\n")
PY
    printf 'runner_exit=%s\n' "$runner_exit" > "$profile/status.txt"
    grep 'Maximum resident set size' "$profile/resource.txt" >> "$profile/status.txt"
    (cd "$output/$CASE" && find . -type f \( -name '*.hex' -o -name '*.vvp' \) \
        -exec sha256sum {} + | sort) > "$profile/generated-input-hashes.txt"
    sed '/^CALIPTRA_PROGRESS_HEARTBEAT /d' "$sim_log" > "$profile/sim-visible.log"
}

run_side reference "$REF_INSTALL" "$ROOT/profiles/reference" "$ROOT/output/reference"
run_side candidate "$CAND_INSTALL" "$ROOT/profiles/candidate" "$ROOT/output/candidate"
cmp "$ROOT/profiles/reference/generated-input-hashes.txt" \
    "$ROOT/profiles/candidate/generated-input-hashes.txt"
cmp "$ROOT/profiles/reference/sim-visible.log" "$ROOT/profiles/candidate/sim-visible.log"
"$ENV/bin/python3.12" - "$ROOT/profiles" "$ROOT/results/instructions.csv" "$ROOT/results/screen.txt" "$BASE" "$CASE" <<'PY'
from pathlib import Path
import sys
root, csv_path, summary_path = map(Path, sys.argv[1:4])
base, case = sys.argv[4:6]
def total(label):
    rows = (root / label / "instructions.txt").read_text().splitlines()
    return int(next(row.split()[1] for row in rows if row.startswith("TOTAL ")))
ref, cand = total("reference"), total("candidate")
delta = (cand - ref) * 100.0 / ref
csv_path.write_text(
    "measurement_base,case,window,variant,instructions,delta_from_reference_pct\n"
    f"{base},{case},100:200,reference,{ref},0.000000\n"
    f"{base},{case},100:200,predecode+setarray,{cand},{delta:.6f}\n")
summary_path.write_text(
    f"measurement_base={base}\ncase={case}\nwindow=100:200\n"
    f"reference_instructions={ref}\ncandidate_instructions={cand}\n"
    f"delta_pct={delta:.6f}\nclears_10_percent_instruction_gate={'yes' if delta <= -10 else 'no'}\n"
    "generated_inputs_identical=yes\nsim_output_identical_except_progress_heartbeat=yes\n")
PY
sha256sum "$ROOT/results"/* > "$ROOT/results/SHA256SUMS"
touch "$ROOT/results/SUCCESS"
