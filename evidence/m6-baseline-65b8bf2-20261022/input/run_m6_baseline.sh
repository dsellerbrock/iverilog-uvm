#!/usr/bin/env bash
set -Eeuo pipefail

BASE=65b8bf2045dfa7a66120bb8c81d8941e97d6daaa
RUN=$(cd .. && pwd)
SCRIPT_ROOT=$PWD
SOURCE=$RUN/build-source
EVIDENCE=$SCRIPT_ROOT/evidence/m6-baseline-65b8bf2-20261022/input
CALIPTRA_INPUT=$SCRIPT_ROOT/evidence/caliptra-top-throughput-20261016/input/threeway
CORPUS_RUNNER=$SCRIPT_ROOT/evidence/m3-sparse-mul-c344-20261018/input/run_json_callgrind.py
QD=/home/dsell/toolchains/qd-bfm-d1529c922da402943148a0fb22648f347e30eed9
CALIPTRA=/home/dsell/toolchains/iverilog-c339
RTL=$CALIPTRA/firmware/caliptra-rtl
ENV=$CALIPTRA/deps
OPENSSL=$CALIPTRA/openssl
GCC_DIR=$CALIPTRA/firmware/xpack-riscv-none-elf-gcc-15.2.0-1/bin
JTAG_VPI=/home/dsell/toolchains/iverilog-uvm-3335fe7ec1495956c8adc5788e9a53b0f1756ecf/caliptra-jtagdpi/jtagdpi.vpi
START=100
END=2100
INSTALL=$RUN/install
CPU=$(awk '/Cpus_allowed_list:/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
CASES=(smoke_test_dma_aes_gcm_short_1_dword smoke_test_sha256 cptra_ss_test_rom)

mkdir -p "$RUN"/{install,logs,results,output,window,bin,callgrind}
test -x "$ENV/bin/python3.12"
test -x "$GCC_DIR/riscv-none-elf-gcc"
test -f "$JTAG_VPI"
test -x /usr/bin/valgrind
test -f "$CALIPTRA_INPUT/mcycle-window-vpi.c"
test -f "$CALIPTRA_INPUT/ecc_secp384r1-deterministic.c"
test -f "$CORPUS_RUNNER"
git clone --filter=blob:none --no-checkout https://github.com/dsellerbrock/iverilog-uvm.git "$SOURCE" \
    > "$RUN/logs/source-clone.log" 2>&1
git -C "$SOURCE" checkout --detach "$BASE" > "$RUN/logs/source-checkout.log" 2>&1
git -C "$SOURCE" submodule update --init --recursive --jobs 3 \
    > "$RUN/logs/source-submodules.log" 2>&1
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
git -C "$SOURCE" submodule status --recursive > "$RUN/results/source-submodules.txt"
test "$(git -C "$RTL" rev-parse HEAD)" = 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e
test "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" = b77e3d899e828d626cfc2a0d26a6b5704cc121e0
test -z "$(git -C "$RTL" status --porcelain --untracked-files=all)"
test -z "$(git -C "$RTL/submodules/adams-bridge" status --porcelain --untracked-files=all)"
for case_name in "${CASES[@]}"; do
    test -f "$RTL/src/integration/test_suites/$case_name/$case_name.yml"
done

(
    cd "$SOURCE"
    sh autoconf.sh
    ./configure --prefix="$INSTALL" --enable-libveriuser \
        CFLAGS='-g -O2 -fno-omit-frame-pointer' CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
    timeout --signal=TERM --kill-after=30s 3600s make -j3
    timeout --signal=TERM --kill-after=30s 900s make install
    timeout --signal=TERM --kill-after=30s 900s make installuvm
) > "$RUN/logs/build.log" 2>&1

mkdir -p "$RUN/window"
(
    cd "$RUN/window"
    "$INSTALL/bin/iverilog-vpi" "$CALIPTRA_INPUT/mcycle-window-vpi.c"
) > "$RUN/logs/window-plugin.log" 2>&1
test -s "$RUN/window/mcycle-window-vpi.vpi"

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
export CALIPTRA_MCYCLE_WINDOW_PLUGIN=$RUN/window/mcycle-window-vpi.vpi
export CALIPTRA_MCYCLE_WINDOW_START=$START
export CALIPTRA_MCYCLE_WINDOW_END=$END
export A5_FIXED_ECC_SOURCE=$CALIPTRA_INPUT/ecc_secp384r1-deterministic.c
export LC_ALL=C
export PYTHONPYCACHEPREFIX=$RUN/pycache
RUNNER=$CALIPTRA_INPUT/run_caliptra_top_profile.py
"$ENV/bin/python3.12" -m py_compile "$RUNNER"

printf 'host=%s\nmeasurement_base=%s\nqd_bfm=%s\ncaliptra_rtl=%s\nrtl_adams_bridge=%s\nuvm_core=%s\nwindow=%s:%s\ncpu=%s\n' \
    "$(hostname)" "$BASE" "$(cat "$QD/qd-bfm.commit")" "$(git -C "$RTL" rev-parse HEAD)" \
    "$(git -C "$RTL/submodules/adams-bridge" rev-parse HEAD)" \
    "$(git -C "$SOURCE/uvm-core" rev-parse HEAD)" "$START" "$END" "$CPU" > "$RUN/results/provenance.txt"
printf 'build_flags=-g -O2 -fno-omit-frame-pointer\nconfigure=--enable-libveriuser\n' \
    >> "$RUN/results/provenance.txt"
perf --version >> "$RUN/results/provenance.txt"
/usr/bin/valgrind --version >> "$RUN/results/provenance.txt"
"$INSTALL/bin/iverilog" -V > "$RUN/results/iverilog-version.txt" 2>&1
"$INSTALL/bin/vvp" -V > "$RUN/results/vvp-version.txt" 2>&1
sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" "$INSTALL/bin/iverilog-vpi" \
    "$RUN/window/mcycle-window-vpi.vpi" > "$RUN/results/binary-sha256.txt"
printf 'test\trepeat\tcycles\telapsed_ns\tcycles_per_second\tlog_sha256\thex_manifest_sha256\n' \
    > "$RUN/results/throughput-samples.tsv"

run_case() {
    local case_name=$1 repeat=$2 profile=${3:-no}
    local label=$case_name-r$repeat${profile:+-$profile}
    local out=$RUN/output/$label evidence=$RUN/results/samples/$label
    mkdir -p "$evidence"
    if [[ "$profile" == perf ]]; then
        export REAL_VVP=$INSTALL/bin/vvp PERF_BIN=$(command -v perf) PROFILE_CPU=$CPU
        test -x "$PERF_BIN"
        export M6_PERF_OUTPUT=$RUN/results/perf/$case_name.data
        mkdir -p "$RUN/results/perf"
        cat > "$RUN/bin/perf-vvp" <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${1:-} == "-V" ]]; then exec "$REAL_VVP" "$@"; fi
exec taskset -c "$PROFILE_CPU" "$PERF_BIN" record -F 99 -g --call-graph fp \
    -o "$M6_PERF_OUTPUT" -- "$REAL_VVP" "$@"
WRAPPER
        chmod +x "$RUN/bin/perf-vvp"
        export VVP_BIN=$RUN/bin/perf-vvp
    else
        export VVP_BIN=$INSTALL/bin/vvp
    fi
    set +e
    timeout --signal=INT --kill-after=60s 1800s taskset -c "$CPU" \
        "$ENV/bin/python3.12" "$RUNNER" --case "$case_name" \
        --case-yaml "$case_name/$case_name.yml" --output "$out" \
        > "$evidence/runner.log" 2>&1
    local rc=$?
    set -e
    test "$rc" -eq 1
    local sim_log=$out/$case_name/sim.log
    local marker
    marker=$(grep '^MCYCLE_WINDOW ' "$sim_log")
    grep -Eq "^MCYCLE_WINDOW start=$START end=$END cycles=$((END-START)) elapsed_ns=[1-9][0-9]*$" <<< "$marker"
    cp "$out/result.json" "$evidence/result.json"
    gzip -1c "$sim_log" > "$evidence/sim.log.gz"
    "$ENV/bin/python3.12" - "$out" "$evidence" "$marker" "$case_name" "$repeat" <<'PY'
import hashlib, json, pathlib, re, sys
root, evidence = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
marker, case_name, repeat = sys.argv[3:]
m = re.fullmatch(r"MCYCLE_WINDOW start=(\d+) end=(\d+) cycles=(\d+) elapsed_ns=(\d+)", marker)
assert m, marker
start, end, cycles, ns = map(int, m.groups())
assert (start, end, cycles) == (100, 2100, 2000) and ns > 0
log = (root / case_name / "sim.log").read_text(errors="replace")
normalized = "".join(line for line in log.splitlines(keepends=True)
                    if not line.startswith(("MCYCLE_WINDOW ", "CALIPTRA_PROGRESS_HEARTBEAT ")))
log_hash = hashlib.sha256(normalized.encode()).hexdigest()
files = [(p.relative_to(root).as_posix(), hashlib.sha256(p.read_bytes()).hexdigest())
         for p in sorted(root.rglob("*.hex"))]
assert files, "no generated firmware hex files"
manifest = "".join(f"{digest}  {name}\n" for name, digest in files)
(evidence / "generated-hex.sha256").write_text(manifest)
hex_hash = hashlib.sha256(manifest.encode()).hexdigest()
if repeat != "0":
    with (evidence.parent.parent / "throughput-samples.tsv").open("a") as stream:
        stream.write(f"{case_name}\t{repeat}\t{cycles}\t{ns}\t{cycles*1e9/ns:.9f}\t{log_hash}\t{hex_hash}\n")
result = json.loads((evidence / "result.json").read_text())
assert result.get("test") == case_name and result.get("passed") is False
# The VPI window plugin calls vpiFinish(0); the runner itself returns 1 for this intentionally partial firmware run.
assert result.get("sim_exit") == 0 and result.get("finish") is None
assert result.get("testcase_fail_markers") == 0
assert result.get("bad_diagnostics") == 0 and result.get("jtag_server_errors") == 0
PY
    gzip -1 "$evidence/runner.log"
    if [[ "$profile" == perf ]]; then
        test -s "$M6_PERF_OUTPUT"
        perf report --stdio --no-children -g -i "$M6_PERF_OUTPUT" \
            > "$RUN/results/perf/$case_name.txt" 2>&1
        gzip -1 "$M6_PERF_OUTPUT"
    fi
    rm -rf "$out"
}

for repeat in 1 2 3; do
    for case_name in "${CASES[@]}"; do run_case "$case_name" "$repeat"; done
done
for case_name in "${CASES[@]}"; do run_case "$case_name" 0 perf; done

"$ENV/bin/python3.12" - "$RUN/results" <<'PY'
import csv, pathlib, statistics, sys
root = pathlib.Path(sys.argv[1])
rows = list(csv.DictReader((root / "throughput-samples.tsv").open(), delimiter="\t"))
summary = root / "throughput-summary.csv"
with summary.open("w", newline="") as stream:
    out = csv.writer(stream)
    out.writerow(("measurement_base", "test", "median_cycles_per_second", "spread_pct", "log_identical", "hex_identical"))
    for name in sorted({row["test"] for row in rows}):
        group = [row for row in rows if row["test"] == name]
        assert len(group) == 3, (name, len(group))
        assert len({row["log_sha256"] for row in group}) == 1, f"normalized logs differ: {name}"
        assert len({row["hex_manifest_sha256"] for row in group}) == 1, f"generated hex differs: {name}"
        values = [float(row["cycles_per_second"]) for row in group]
        median = statistics.median(values)
        spread = (max(values) - min(values)) / median * 100
        out.writerow(("65b8bf2045dfa7a66120bb8c81d8941e97d6daaa", name, f"{median:.6f}", f"{spread:.3f}", "yes", "yes"))
PY

export IVERILOG=$INSTALL/bin/iverilog
export IVERILOG_VPI=$INSTALL/bin/iverilog-vpi
export UVM_DPI=$INSTALL/lib/ivl/uvm_dpi.vpi
export VALGRIND_LIB=/usr/libexec/valgrind
mkdir -p "$SOURCE/benchmarks/sim-hotspots" "$RUN/bin"
cp "$CORPUS_RUNNER" "$SOURCE/benchmarks/sim-hotspots/run_json_callgrind_m6.py"
make_callgrind_wrapper() {
    local name=$1
    cat > "$RUN/bin/vvp-$name" <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail
name=$(basename "$(dirname "$PWD")")-$(basename "$PWD")
exec /usr/bin/valgrind --quiet --tool=callgrind \
    --callgrind-out-file="$M6_CALLGRIND_DIR/$name.callgrind" \
    --log-file="$M6_CALLGRIND_DIR/$name.valgrind.log" \
    "$M6_REAL_VVP" "$@"
WRAPPER
    chmod +x "$RUN/bin/vvp-$name"
}
export M6_REAL_VVP=$INSTALL/bin/vvp M6_CALLGRIND_DIR=$RUN/callgrind
make_callgrind_wrapper reference
make_callgrind_wrapper candidate
python3 "$SOURCE/benchmarks/sim-hotspots/run_json_callgrind_m6.py" \
    "$RUN/bin/vvp-reference" "$RUN/bin/vvp-candidate" 1 > "$RUN/results/corpus.json"
"$ENV/bin/python3.12" - "$RUN/results/corpus.json" "$RUN/callgrind" "$RUN/results/callgrind-18.csv" "$BASE" <<'PY'
import csv, json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
profiles, output, base = pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]), sys.argv[4]
rows = []
for name, item in sorted(data["benchmarks"].items()):
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"{name}: corpus/output comparison failed")
    counts = []
    for side in ("reference", "candidate"):
        path = profiles / f"{name}-01-{side}.callgrind"
        summaries = [int(line.split()[1]) for line in path.read_text().splitlines() if line.startswith("summary:")]
        if len(summaries) != 1:
            raise SystemExit(f"expected one Callgrind summary in {path}")
        counts.append(summaries[0])
    rows.append((base, name, counts[0], counts[1], "yes"))
if len(rows) != 18:
    raise SystemExit(f"expected 18 workloads, got {len(rows)}")
with output.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "benchmark", "reference_ir", "candidate_ir", "output_identical"))
    writer.writerows(rows)
PY
rm -rf "$RUN/callgrind" "$SOURCE/benchmarks/sim-hotspots/run_json_callgrind_m6.py"
touch "$RUN/results/SUCCESS"
find "$RUN/results" -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum \
    > "$RUN/results/SHA256SUMS"
tar -czf "$RUN/m6-baseline-results.tgz" -C "$RUN" results
