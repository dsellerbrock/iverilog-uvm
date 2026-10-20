#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-tiered
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=08:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020
BASE=8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1
INPUT=$ROOT/input
GITHUB=https://github.com/dsellerbrock/iverilog-uvm.git
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
C339=/home/dsell/toolchains/iverilog-c339
RTL=$C339/firmware/caliptra-rtl
ENV=$C339/deps
OPENSSL=$C339/openssl
GCC_DIR=$C339/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
JTAG_VPI=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf/caliptra-jtagdpi/jtagdpi.vpi
RUNNER=$INPUT/run_caliptra_top_profile.py
WINDOW_START=100
WINDOW_END=2100

mkdir -p "$ROOT"/{source,install,logs,results,input,profiles,window,caliptra,runners}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"
test -s "$INPUT/candidate.patch" && test -s "$INPUT/run_json_callgrind.py"
(cd "$INPUT" && sha256sum --check SHA256SUMS)
test -x "$ENV/bin/python3.12" && test -x "$GCC_DIR/riscv-none-elf-gcc"
test -f "$JTAG_VPI"
test "$(git -C "$RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" = b77e3d899e828d626cfc2a0d26a6b5704cc121e0
test -z "$(git -C "$RTL" status --porcelain --untracked-files=all)"
test -z "$(git -C "$RTL/submodules/adams-bridge" status --porcelain --untracked-files=all)"

for side in reference candidate stats; do
    SOURCE=$ROOT/source/$side
    INSTALL=$ROOT/install/$side
    if [[ -x "$INSTALL/bin/vvp" ]]; then
        test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
        if [[ "$side" != reference ]]; then
            git -C "$SOURCE" add -N benchmarks/sim-hotspots/randomize_t0_disabled.sv docs/performance/SOLVER.md
            git -C "$SOURCE" diff --binary HEAD > "$ROOT/results/reused-$side.patch"
            cmp "$ROOT/results/reused-$side.patch" "$INPUT/candidate.patch"
        fi
        continue
    fi
    if [[ "$side" == reference ]]; then
        git clone --no-checkout "$GITHUB" "$SOURCE" > "$ROOT/logs/clone-$side.log" 2>&1
    else
        git clone --shared --no-checkout "$ROOT/source/reference" "$SOURCE" > "$ROOT/logs/clone-$side.log" 2>&1
    fi
    git -C "$SOURCE" checkout --detach "$BASE" > "$ROOT/logs/checkout-$side.log" 2>&1
    if [[ "$side" != reference ]]; then
        git -C "$SOURCE" apply --check "$INPUT/candidate.patch"
        git -C "$SOURCE" apply "$INPUT/candidate.patch" > "$ROOT/logs/patch-$side.log"
    fi
    git -C "$SOURCE" submodule update --init --recursive --jobs 4 > "$ROOT/logs/submodules-$side.log" 2>&1
    test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
    (
        cd "$SOURCE"
        sh autoconf.sh
        flags=(--prefix="$INSTALL" --enable-libveriuser)
        if [[ "$side" == stats ]]; then flags+=(--enable-perf-stats); fi
        ./configure "${flags[@]}" CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
        timeout --signal=TERM --kill-after=30s 3600s make -j4
        timeout --signal=TERM --kill-after=30s 900s make install
        timeout --signal=TERM --kill-after=30s 900s make installuvm
    ) > "$ROOT/logs/build-$side.log" 2>&1
    sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" "$INSTALL/bin/iverilog-vpi" \
        > "$ROOT/results/binaries-$side.sha256"
done

CPU=$(awk '/Cpus_allowed_list:/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'base=%s\ncpu=%s\ncpus_per_task=4\nwindow=%s:%s\n' "$BASE" "$CPU" \
    "$WINDOW_START" "$WINDOW_END" > "$ROOT/results/provenance.txt"
sha256sum "$INPUT"/* > "$ROOT/results/inputs.sha256"

# Interleaved one-run Callgrind and byte-strict comparison for all 18 workloads.
CAND_SOURCE=$ROOT/source/candidate
cp "$INPUT/run_json_callgrind.py" "$CAND_SOURCE/benchmarks/sim-hotspots/run_json_callgrind.py"
mkdir -p "$ROOT/profiles" "$ROOT/results"
make_callgrind_wrapper() {
    local name=$1 runtime=$2
    local path=$ROOT/runners/$name
    cat > "$path" <<WRAPPER
#!/usr/bin/env bash
set -Eeuo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
args=(--quiet --tool=callgrind)
if [[ "\$name" == waveform_fst-* ]]; then args+=(--fair-sched=yes); fi
exec /usr/bin/valgrind "\${args[@]}" --callgrind-out-file="$ROOT/profiles/\$name.callgrind" \\
  --log-file="$ROOT/profiles/\$name.valgrind.log" "$runtime" "\$@"
WRAPPER
    chmod +x "$path"
}
make_callgrind_wrapper reference "$ROOT/install/reference/bin/vvp"
make_callgrind_wrapper candidate "$ROOT/install/candidate/bin/vvp"
export VALGRIND_LIB=/usr/libexec/valgrind
export REFERENCE_IVERILOG=$ROOT/install/reference/bin/iverilog
export IVERILOG=$ROOT/install/candidate/bin/iverilog
export IVERILOG_VPI=$ROOT/install/candidate/bin/iverilog-vpi
export UVM_DPI=$ROOT/install/candidate/lib/ivl/uvm_dpi.vpi
if [[ ! -s "$ROOT/results/corpus-reconciled.json" ]]; then
    python3 "$CAND_SOURCE/benchmarks/sim-hotspots/run_json_callgrind.py" \
        "$ROOT/runners/reference" "$ROOT/runners/candidate" 1 > "$ROOT/results/corpus.json"
    cp "$ROOT/results/corpus.json" "$ROOT/results/corpus-reconciled.json"
fi
python3 - "$ROOT" "$BASE" <<'PY'
import csv, json, sys
from pathlib import Path
root, base = Path(sys.argv[1]), sys.argv[2]
data = json.loads((root / "results/corpus-reconciled.json").read_text())
rows = []
for name, item in sorted(data["benchmarks"].items()):
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"{name}: output mismatch or failed run")
    counts = []
    for side in ("reference", "candidate"):
        profile_name = (f"fst-repro-{side}.callgrind" if name == "waveform_fst"
                        and (root / "profiles" / f"fst-repro-{side}.callgrind").exists()
                        else f"{name}-01-{side}.callgrind")
        path = root / "profiles" / profile_name
        values = [line.split()[1] for line in path.read_text().splitlines()
                  if line.startswith("summary:")]
        if len(values) != 1:
            raise SystemExit(f"missing Callgrind summary: {path}")
        counts.append(int(values[0]))
    rows.append((name, *counts, (counts[1] / counts[0] - 1) * 100))
if len(rows) != 18:
    raise SystemExit(f"expected 18 workloads, got {len(rows)}")
with (root / "results/callgrind.csv").open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "workload", "main_ir", "candidate_ir", "candidate_delta_pct", "outputs_identical"))
    for name, ref, cand, delta in rows:
        writer.writerow((base, name, ref, cand, f"{delta:.6f}", "yes"))
PY

# The disabled-constraint case is the only new production fast path.
FIXTURE=$CAND_SOURCE/benchmarks/sim-hotspots/randomize_t0_disabled.sv
for side in reference candidate; do
    "$ROOT/install/$side/bin/iverilog" -g2017 -s main -o "$ROOT/results/t0-$side.vvp" "$FIXTURE" \
        > "$ROOT/results/t0-$side.compile.log" 2>&1
    timeout --signal=TERM --kill-after=10s 600s /usr/bin/valgrind --quiet --tool=callgrind \
        --callgrind-out-file="$ROOT/profiles/t0-$side.callgrind" \
        "$ROOT/install/$side/bin/vvp" -n "$ROOT/results/t0-$side.vvp" \
        > "$ROOT/results/t0-$side.out" 2> "$ROOT/results/t0-$side.err"
    timeout --signal=TERM --kill-after=10s 600s /usr/bin/valgrind --quiet --tool=callgrind \
        --callgrind-out-file="$ROOT/profiles/t4-$side.callgrind" \
        "$ROOT/install/$side/bin/vvp" -n "$ROOT/results/t0-$side.vvp" +t4 \
        > "$ROOT/results/t4-$side.out" 2> "$ROOT/results/t4-$side.err"
done
cmp "$ROOT/results/t0-reference.out" "$ROOT/results/t0-candidate.out"
cmp "$ROOT/results/t0-reference.err" "$ROOT/results/t0-candidate.err"
cmp "$ROOT/results/t4-reference.out" "$ROOT/results/t4-candidate.out"
cmp "$ROOT/results/t4-reference.err" "$ROOT/results/t4-candidate.err"
python3 - "$ROOT" <<'PY'
import csv, sys
from pathlib import Path
root = Path(sys.argv[1])
with (root / "results/tier-focus.csv").open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("tier", "main_ir", "candidate_ir", "speedup", "outputs_identical"))
    for tier in ("t0", "t4"):
        counts = []
        for side in ("reference", "candidate"):
            profile = root / "profiles" / f"{tier}-{side}.callgrind"
            summaries = [line.split()[1] for line in profile.read_text().splitlines()
                         if line.startswith("summary:")]
            if len(summaries) != 1:
                raise SystemExit(f"missing Callgrind summary: {profile}")
            counts.append(int(summaries[0]))
        writer.writerow((tier.upper(), counts[0], counts[1], f"{counts[0]/counts[1]:.6f}", "yes"))
PY

# Record per-call tier counters for corpus tests and a representative Caliptra UVM window.
python3 "$INPUT/collect_tier_hist.py" "$ROOT/source/stats" "$ROOT/install/stats" \
    "$ROOT/results/tier-hist-corpus" > "$ROOT/logs/tier-hist-corpus.log"

mkdir -p "$ROOT/caliptra"/{out,logs,window,pycache}
for side in reference candidate stats; do
    (
        cd "$ROOT/caliptra/window"
        "$ROOT/install/$side/bin/iverilog-vpi" "$INPUT/mcycle-window-vpi.c" > "$ROOT/logs/window-$side.log" 2>&1
        mv mcycle-window-vpi.vpi "$side.vpi"
    )
done
cases=(smoke_test_dma_aes_gcm_short_1_dword smoke_test_sha256 cptra_ss_test_rom)
run_caliptra() {
    local side=$1 case_name=$2 stats=${3:-no}
    local install=$ROOT/install/$side source=$ROOT/source/$side
    local output=$ROOT/caliptra/out/$case_name-$side evidence=$ROOT/caliptra/logs/$case_name-$side
    mkdir -p "$evidence" "$ROOT/caliptra/pycache/$side"
    export PATH="$install/bin:$ENV/bin:$GCC_DIR:$OPENSSL/bin:/usr/bin:/bin"
    export LD_LIBRARY_PATH="$install/lib:$ENV/lib:$OPENSSL/lib"
    export CALIPTRA_BFM_REPO=$QD CALIPTRA_MBEDTLS_ROOT=$ENV CALIPTRA_RTL=$RTL
    export CALIPTRA_GCC_PREFIX=$GCC_DIR/riscv-none-elf- CALIPTRA_JTAGDPI_VPI=$JTAG_VPI
    export CALIPTRA_BFM_PROFILE=$RTL/src/integration/config/caliptra_top_tb.vf
    export CALIPTRA_PRIM_ROOT=$RTL/src/caliptra_prim_generic CALIPTRA_PRIM_MODULE_PREFIX=caliptra_prim_generic
    export IVERILOG_BIN=$install/bin/iverilog IVERILOG_VPI_BIN=$install/bin/iverilog-vpi
    export IVERILOG_SOURCE_ROOT=$source VVP_BIN=$install/bin/vvp
    export PYTHONPYCACHEPREFIX=$ROOT/caliptra/pycache/$side
    export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$ROOT/caliptra/window/$side.vpi
    export CALIPTRA_MCYCLE_WINDOW_START=$WINDOW_START CALIPTRA_MCYCLE_WINDOW_END=$WINDOW_END
    export A5_FIXED_ECC_SOURCE=$INPUT/ecc_secp384r1-deterministic.c
    if [[ "$stats" == yes ]]; then export IVL_PERF_STATS=1; else unset IVL_PERF_STATS || true; fi
    set +e
    /usr/bin/time -v -o "$evidence/resource.txt" timeout --signal=INT --kill-after=60s 1800s \
        taskset -c "$CPU" "$ENV/bin/python3.12" "$RUNNER" --case "$case_name" \
        --case-yaml "$case_name/$case_name.yml" --output "$output" > "$evidence/runner.log" 2>&1
    rc=$?
    set -e
    test "$rc" -eq 1
    test -f "$output/$case_name/sim.log"
    grep -q "^MCYCLE_WINDOW start=$WINDOW_START end=$WINDOW_END cycles=$((WINDOW_END-WINDOW_START)) elapsed_ns=" \
        "$output/$case_name/sim.log"
    find "$output" -type f -name '*.hex' -print0 | sort -z | xargs -0 -r sha256sum > "$evidence/generated-hex.sha256"
    cp "$output/$case_name/sim.log" "$evidence/sim.log"
    cp "$output/result.json" "$evidence/result.json"
}
for case_name in "${cases[@]}"; do
    run_caliptra reference "$case_name"
    run_caliptra candidate "$case_name"
    run_caliptra stats "$case_name" yes
done
python3 - "$ROOT" "${cases[@]}" <<'PY'
import hashlib, json, re, sys
from pathlib import Path
root, cases = Path(sys.argv[1]), sys.argv[2:]
def normalized(path):
    return "\n".join(line for line in path.read_text(errors="replace").splitlines()
                     if not line.startswith(("MCYCLE_WINDOW ", "CALIPTRA_PROGRESS_HEARTBEAT ", "VVP_PERF_STATS ")))
def hex_files(path):
    return {p.relative_to(path).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob("*.hex"))}
summary = {}
for case in cases:
    outputs = {}
    for side in ("reference", "candidate", "stats"):
        outputs[side] = root / "caliptra/out" / f"{case}-{side}" / case
    if hex_files(outputs["reference"]) != hex_files(outputs["candidate"]):
        raise SystemExit(f"{case}: base/candidate firmware images differ")
    if normalized(outputs["reference"] / "sim.log") != normalized(outputs["candidate"] / "sim.log"):
        raise SystemExit(f"{case}: base/candidate simulation output differs")
    if normalized(outputs["candidate"] / "sim.log") != normalized(outputs["stats"] / "sim.log"):
        raise SystemExit(f"{case}: stats instrumentation changed simulation output")
    tiers = re.findall(r"^VVP_PERF_STATS (\{.*\})$", (outputs["stats"] / "sim.log").read_text(), re.MULTILINE)
    if len(tiers) != 1:
        raise SystemExit(f"{case}: expected one tier report")
    report = json.loads(tiers[0])
    summary[case] = {"tiers": report["randomize_tiers"], "z3": report["z3"]}
(root / "results/tier-hist-caliptra.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY

(cd "$ROOT" && find results -type f ! -name SHA256SUMS -print0 \
    | sort -z | xargs -0 sha256sum) > "$ROOT/results/SHA256SUMS"
touch "$ROOT/results/SUCCESS"
