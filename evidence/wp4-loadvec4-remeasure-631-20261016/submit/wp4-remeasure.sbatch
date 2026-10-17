#!/usr/bin/env bash
#SBATCH --job-name=a5-wp4-631-remeasure
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-loadvec4-631-remeasure-20261016/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-loadvec4-631-remeasure-20261016/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-loadvec4-631-remeasure-20261016
TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/loadvec4-profile-374b-20261016-r2/source/iverilog-uvm
TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/tools/root
VALGRIND=$TOOLS/usr/bin/valgrind
BASE=631b7a869faaa05216d8749224520227b4b23d43
CAND=51987d3cccfe2ddb862eb01b9a7388eb687276c6
PR_BRANCH=agent/a5-perf-loadvec4-374b
GITHUB=https://github.com/dsellerbrock/iverilog-uvm.git

mkdir -p "$ROOT"/{source,install,logs,results,profiles,programs,wrappers,runner,submit}
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$ROOT/results/job-exit-code"
    touch "$ROOT/results/DONE"
    tar -czf "$ROOT/results-bundle.tgz" -C "$ROOT" results logs profiles
    exit "$rc"
}
trap finish EXIT

test -d "$TEMPLATE/.git"
test -x "$VALGRIND"
export VALGRIND_LIB=$TOOLS/usr/libexec/valgrind
printf 'measurement_base=%s\ncandidate_commit=%s\ncampaign_base=f9f8e0a79f230f38da6cbb4445994ad1075ad531\n' \
    "$BASE" "$CAND" > "$ROOT/results/provenance.txt"
printf 'host=%s\n' "$(hostname)" >> "$ROOT/results/provenance.txt"
printf 'valgrind=%s\n' "$("$VALGRIND" --version)" >> "$ROOT/results/provenance.txt"

checkout_side() {
    side=$1
    revision=$2
    source=$ROOT/source/$side
    git clone --shared --no-checkout "$TEMPLATE" "$source" > "$ROOT/logs/clone-$side.log" 2>&1
    git -C "$source" remote add github "$GITHUB"
    git -C "$source" fetch github main "$PR_BRANCH" > "$ROOT/logs/fetch-$side.log" 2>&1
    git -C "$source" checkout --detach "$revision" > "$ROOT/logs/checkout-$side.log" 2>&1
    test "$(git -C "$source" rev-parse HEAD)" = "$revision"
    git -C "$source" submodule update --init --recursive --jobs 4 \
        > "$ROOT/logs/submodules-$side.log" 2>&1
    test -z "$(git -C "$source" status --porcelain --untracked-files=all)"
    git -C "$source" submodule status --recursive > "$ROOT/results/submodules-$side.txt"
}
checkout_side reference "$BASE"
checkout_side candidate "$CAND"

build_side() {
    side=$1
    source=$ROOT/source/$side
    install=$ROOT/install/$side
    mkdir -p "$install"
    (
        cd "$source"
        sh autoconf.sh
        ./configure --prefix="$install" --enable-libveriuser CFLAGS='-g0 -O2' CXXFLAGS='-g0 -O2'
        timeout --signal=TERM --kill-after=30s 5400s make -j4
        timeout --signal=TERM --kill-after=30s 1800s make install
        timeout --signal=TERM --kill-after=30s 1800s make installuvm
    ) > "$ROOT/logs/build-$side.log" 2>&1
    "$install/bin/iverilog" -V > "$ROOT/results/iverilog-$side.txt" 2>&1
    "$install/bin/vvp" -V > "$ROOT/results/vvp-$side.txt" 2>&1
    sha256sum "$install/bin/iverilog" "$install/bin/vvp" \
        "$install/bin/iverilog-vpi" > "$ROOT/results/binaries-$side.sha256"
}
build_side reference
build_side candidate

REF_INSTALL=$ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate
CAND_SOURCE=$ROOT/source/candidate
export PATH="$CAND_INSTALL/bin:$PATH"
export IVERILOG="$CAND_INSTALL/bin/iverilog"
export VVP="$CAND_INSTALL/bin/vvp"
export IVERILOG_BIN="$CAND_INSTALL/bin/iverilog"
export IVERILOG_VPI_BIN="$CAND_INSTALL/bin/iverilog-vpi"
export IVERILOG_VPI="$CAND_INSTALL/bin/iverilog-vpi"
UVM_DPI=$(find "$CAND_INSTALL" -type f -name uvm_dpi.vpi -print -quit)
test -n "$UVM_DPI" && test -s "$UVM_DPI"
export UVM_DPI
export LD_LIBRARY_PATH="$CAND_INSTALL/lib:$REF_INSTALL/lib:${LD_LIBRARY_PATH-}"

run_gate() {
    name=$1
    limit=$2
    shift 2
    if /usr/bin/time -v -o "$ROOT/logs/$name.time" \
        timeout --signal=TERM --kill-after=30s "$limit" "$@" \
        > "$ROOT/logs/$name.log" 2>&1; then
        printf '%s\t0\n' "$name" >> "$ROOT/results/gates.tsv"
    else
        rc=$?
        printf '%s\t%s\n' "$name" "$rc" >> "$ROOT/results/gates.tsv"
        return "$rc"
    fi
}
: > "$ROOT/results/gates.tsv"
run_gate make-check 5400 make -C "$CAND_SOURCE" -j4 check
run_gate fpga-install 1800 make -C "$CAND_SOURCE/tgt-fpga" install
run_gate ivtest-gate 14400 bash "$CAND_SOURCE/.github/ivtest_gate.sh"
run_gate json-suite 14400 bash -c 'cd "$1/ivtest" && python3 ./vvp_reg.py' _ "$CAND_SOURCE"
run_gate uvm-real-dpi 14400 bash -c 'cd "$1" && bash .github/uvm_test.sh' _ "$CAND_SOURCE"
test "$(wc -l < "$ROOT/results/gates.tsv")" -eq 5

CPU=$(awk '/Cpus_allowed_list/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'cpu=%s\ncpus_per_task=4\nmemory=8G\n' "$CPU" > "$ROOT/results/environment.txt"
printf 'reference=%s\ncandidate=%s\n' "$BASE" "$CAND" >> "$ROOT/results/environment.txt"

for side in reference candidate; do
    install=$ROOT/install/$side
    "$install/bin/iverilog" -g2012 -s sv_vpi_wide_index \
        -o "$ROOT/programs/edge-$side.vvp" \
        "$CAND_SOURCE/ivtest/ivltests/sv_vpi_wide_index.v" \
        > "$ROOT/logs/edge-compile-$side.log" 2>&1
    "$install/bin/vvp" "$ROOT/programs/edge-$side.vvp" \
        > "$ROOT/results/edge-$side.out" 2> "$ROOT/results/edge-$side.err"
    grep -q '^PASSED$' "$ROOT/results/edge-$side.out"
done
cmp "$ROOT/results/edge-reference.out" "$ROOT/results/edge-candidate.out"
cmp "$ROOT/results/edge-reference.err" "$ROOT/results/edge-candidate.err"

"$CAND_INSTALL/bin/iverilog" -g2012 -s converter_wide_index \
    -o "$ROOT/programs/converter-wide-index.vvp" "$ROOT/input/converter-wide-index.sv" \
    > "$ROOT/logs/converter-compile.log" 2>&1
for side in reference candidate; do
    taskset -c "$CPU" "$VALGRIND" --quiet --tool=callgrind \
        --callgrind-out-file="$ROOT/profiles/converter-$side.callgrind" \
        --log-file="$ROOT/profiles/converter-$side.valgrind.log" \
        "$ROOT/install/$side/bin/vvp" "$ROOT/programs/converter-wide-index.vvp" \
        > "$ROOT/results/converter-$side.out" 2> "$ROOT/results/converter-$side.err"
    grep -q '^PASS wide converter screen ' "$ROOT/results/converter-$side.out"
done
cmp "$ROOT/results/converter-reference.out" "$ROOT/results/converter-candidate.out"
cmp "$ROOT/results/converter-reference.err" "$ROOT/results/converter-candidate.err"

for side in reference candidate; do
    runtime=$ROOT/install/$side/bin/vvp
    cat > "$ROOT/wrappers/callgrind-$side" <<EOF
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
if [[ "\$name" == waveform_fst-* ]]; then
    exec "$VALGRIND" --quiet --tool=callgrind --fair-sched=yes \\
        --callgrind-out-file="$ROOT/profiles/\$name.callgrind" \\
        --log-file="$ROOT/profiles/\$name.valgrind.log" "$runtime" "\$@"
fi
exec "$VALGRIND" --quiet --tool=callgrind \\
    --callgrind-out-file="$ROOT/profiles/\$name.callgrind" \\
    --log-file="$ROOT/profiles/\$name.valgrind.log" "$runtime" "\$@"
EOF
    chmod +x "$ROOT/wrappers/callgrind-$side"
done
cp "$ROOT/input/run_json_callgrind.py" "$CAND_SOURCE/benchmarks/sim-hotspots/"
export A5_SIM_HOTSPOTS_DIR="$CAND_SOURCE/benchmarks/sim-hotspots"
python3 "$CAND_SOURCE/benchmarks/sim-hotspots/run_json_callgrind.py" \
    "$ROOT/wrappers/callgrind-reference" "$ROOT/wrappers/callgrind-candidate" 1 \
    > "$ROOT/results/corpus-callgrind.json"
python3 - "$ROOT/results/corpus-callgrind.json" "$ROOT/profiles" "$ROOT/results/corpus-instructions.csv" <<'PY'
import csv, json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
profiles = Path(sys.argv[2])
rows = []
for name, item in sorted(data["benchmarks"].items()):
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"{name}: output comparison failed")
    counts = []
    for side in ("reference", "candidate"):
        path = profiles / f"{name}-01-{side}.callgrind"
        summaries = [line.split()[1] for line in path.read_text().splitlines()
                     if line.startswith("summary:")]
        if len(summaries) != 1:
            raise SystemExit(f"{name}/{side}: missing Callgrind summary")
        counts.append(int(summaries[0]))
    ref, cand = counts
    pct = (cand - ref) * 100.0 / ref
    rows.append((name, ref, cand, pct))
if len(rows) != 18:
    raise SystemExit(f"expected 18 corpus rows, found {len(rows)}")
with Path(sys.argv[3]).open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "benchmark", "reference_ir", "candidate_ir", "delta_pct", "output_identical"))
    for name, ref, cand, pct in rows:
        writer.writerow(("631b7a869faaa05216d8749224520227b4b23d43", name,
                         ref, cand, f"{pct:.6f}", "yes"))
bad = [(name, pct) for name, _, _, pct in rows if pct >= 2.0]
if bad:
    raise SystemExit(f"non-target instruction regression gate failed: {bad}")
PY

cp "$ROOT/input/run_json_warmup_r4.py" "$ROOT/runner/run_json_warmup_r4.py"
PATH="$CAND_INSTALL/bin:$PATH" \
IVERILOG="$CAND_INSTALL/bin/iverilog" \
IVERILOG_VPI="$CAND_INSTALL/bin/iverilog-vpi" \
UVM_DPI="$UVM_DPI" \
A5_SIM_HOTSPOTS_DIR="$CAND_SOURCE/benchmarks/sim-hotspots" \
    python3 "$ROOT/runner/run_json_warmup_r4.py" \
        "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" 3 \
        > "$ROOT/results/final-wall-3.json"
python3 - "$ROOT/results/final-wall-3.json" "$ROOT/results/final-wall-summary.csv" <<'PY'
import csv, json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
rows = []
for name, item in sorted(data["benchmarks"].items()):
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"{name}: final wall output comparison failed")
    summary = item["summary"]
    ref = summary["reference"]["wall_seconds"]
    cand = summary["candidate"]["wall_seconds"]
    rows.append((name, ref["median"], ref["spread_pct"], cand["median"], cand["spread_pct"]))
if len(rows) != 18:
    raise SystemExit(f"expected 18 final wall rows, found {len(rows)}")
with Path(sys.argv[2]).open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "benchmark", "reference_median_s", "reference_spread_pct",
                     "candidate_median_s", "candidate_spread_pct"))
    for row in rows:
        writer.writerow(("631b7a869faaa05216d8749224520227b4b23d43", *row))
PY

python3 - "$ROOT/profiles/converter-reference.callgrind" \
    "$ROOT/profiles/converter-candidate.callgrind" "$ROOT/results/converter-instructions.csv" <<'PY'
import csv, sys
from pathlib import Path
def summary(path):
    rows = [line.split()[1] for line in Path(path).read_text().splitlines()
            if line.startswith("summary:")]
    if len(rows) != 1:
        raise SystemExit(f"bad Callgrind summary in {path}")
    return int(rows[0])
ref, cand = map(summary, sys.argv[1:3])
pct = (cand - ref) * 100.0 / ref
with Path(sys.argv[3]).open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "reference_ir", "candidate_ir", "delta_pct", "output_identical"))
    writer.writerow(("631b7a869faaa05216d8749224520227b4b23d43", ref, cand, f"{pct:.6f}", "yes"))
if pct > -10.0:
    raise SystemExit(f"focused improvement {pct:.6f}% misses the 10% gate")
PY

sha256sum "$ROOT/results/"* "$ROOT/profiles/"* "$ROOT/logs/"* \
    > "$ROOT/results/SHA256SUMS"
touch "$ROOT/results/SUCCESS"
