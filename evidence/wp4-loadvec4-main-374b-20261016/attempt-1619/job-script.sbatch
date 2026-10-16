#!/usr/bin/env bash
#SBATCH --job-name=a5-conv-374b-build
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r1/logs/%x-%j.out

set -Eeuo pipefail

ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp4-converter-screen-374b-20261016-r1
BASE=374b037e7c8fba7097e0b86b05be7956ca6b5487
TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/loadvec4-profile-374b-20261016-r2/source/iverilog-uvm
INPUT=$ROOT/input
TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/tools/root
VALGRIND=$TOOLS/usr/bin/valgrind
RESULTS=$ROOT/build-screen

mkdir -p "$ROOT/source" "$ROOT/install" "$ROOT/programs" "$ROOT/profiles" "$ROOT/logs" "$RESULTS"
finish() {
    local rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(git -C "$TEMPLATE" rev-parse HEAD)" = "$BASE"
test -x "$VALGRIND" && test -d "$TOOLS/usr/libexec/valgrind"
export VALGRIND_LIB=$TOOLS/usr/libexec/valgrind
"$VALGRIND" --version > "$RESULTS/valgrind-version.txt"

for side in reference candidate; do
    SOURCE=$ROOT/source/$side
    git clone --shared --no-checkout "$TEMPLATE" "$SOURCE" > "$ROOT/logs/clone-$side.log" 2>&1
    git -C "$SOURCE" checkout --detach "$BASE" > "$ROOT/logs/checkout-$side.log" 2>&1
    git -C "$SOURCE" submodule update --init --recursive > "$ROOT/logs/submodules-$side.log" 2>&1
    test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
    test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
done

CANDIDATE=$ROOT/source/candidate
git -C "$CANDIDATE" apply --check "$INPUT/candidate.patch"
git -C "$CANDIDATE" apply "$INPUT/candidate.patch" > "$RESULTS/patch.log"
cp "$INPUT/sv_vpi_wide_index.v" "$CANDIDATE/ivtest/ivltests/"
cp "$INPUT/sv_vpi_wide_index.json" "$CANDIDATE/ivtest/vvp_tests/"
cp "$INPUT/run_json_callgrind.py" "$CANDIDATE/benchmarks/sim-hotspots/"
grep -q '^sv_vpi_wide_index vvp_tests/sv_vpi_wide_index.json$' "$CANDIDATE/ivtest/regress-vvp.list"

build_side() {
    local side=$1 source=$ROOT/source/$1 install=$ROOT/install/$1
    (
        cd "$source"
        sh autoconf.sh
        ./configure --prefix="$install" --enable-libveriuser CFLAGS='-g0 -O2' CXXFLAGS='-g0 -O2'
        timeout --signal=TERM --kill-after=15s 5400s make -j4
        timeout --signal=TERM --kill-after=15s 1800s make install
        timeout --signal=TERM --kill-after=15s 1800s make installuvm
    ) > "$ROOT/logs/build-$side.log" 2>&1
}
build_side reference
build_side candidate

sha256sum "$ROOT/install/reference/bin/iverilog" "$ROOT/install/reference/bin/vvp" \
    "$ROOT/install/candidate/bin/iverilog" "$ROOT/install/candidate/bin/vvp" \
    "$INPUT/candidate.patch" "$INPUT/converter-wide-index.sv" \
    "$INPUT/sv_vpi_wide_index.v" "$TEMPLATE/vvp/vpi_priv.cc" \
    "$TEMPLATE/vvp/vvp_net.h" > "$RESULTS/provenance.sha256"
printf 'measurement_base=%s\nreference_source=%s\ncandidate_source=%s\n' \
    "$BASE" "$ROOT/source/reference" "$ROOT/source/candidate" > "$RESULTS/provenance.txt"
git -C "$ROOT/source/reference" submodule status > "$RESULTS/reference-submodules.txt"
git -C "$ROOT/source/candidate" submodule status > "$RESULTS/candidate-submodules.txt"

CPU=$(awk '/Cpus_allowed_list/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'cpu=%s\n' "$CPU" > "$RESULTS/cpu.txt"
for side in reference candidate; do
    INSTALL=$ROOT/install/$side
    mkdir -p "$ROOT/programs/$side" "$ROOT/profiles/$side"
    "$INSTALL/bin/iverilog" -g2012 -s converter_wide_index \
        -o "$ROOT/programs/$side/converter.vvp" "$INPUT/converter-wide-index.sv" \
        > "$ROOT/programs/$side/converter.compile.log" 2>&1
    "$INSTALL/bin/iverilog" -g2012 -s sv_vpi_wide_index \
        -o "$ROOT/programs/$side/edge.vvp" "$INPUT/sv_vpi_wide_index.v" \
        > "$ROOT/programs/$side/edge.compile.log" 2>&1
    "$INSTALL/bin/vvp" "$ROOT/programs/$side/edge.vvp" \
        > "$RESULTS/edge-$side.out" 2> "$RESULTS/edge-$side.err"
    grep -q '^PASSED$' "$RESULTS/edge-$side.out"
done
cmp "$ROOT/programs/reference/converter.vvp" "$ROOT/programs/candidate/converter.vvp"
cmp "$ROOT/programs/reference/edge.vvp" "$ROOT/programs/candidate/edge.vvp"
cmp "$RESULTS/edge-reference.out" "$RESULTS/edge-candidate.out"
cmp "$RESULTS/edge-reference.err" "$RESULTS/edge-candidate.err"

for side in reference candidate; do
    INSTALL=$ROOT/install/$side
    timeout --signal=TERM --kill-after=15s 1800s taskset -c "$CPU" \
        "$VALGRIND" --quiet --tool=callgrind \
        --callgrind-out-file="$ROOT/profiles/$side/converter-wide-index.callgrind" \
        --log-file="$ROOT/profiles/$side/converter-wide-index.valgrind.log" \
        "$INSTALL/bin/vvp" "$ROOT/programs/$side/converter.vvp" \
        > "$RESULTS/converter-$side.out" 2> "$RESULTS/converter-$side.err"
    grep -q '^PASS wide converter screen ' "$RESULTS/converter-$side.out"
done
cmp "$RESULTS/converter-reference.out" "$RESULTS/converter-candidate.out"
cmp "$RESULTS/converter-reference.err" "$RESULTS/converter-candidate.err"

python3 - "$ROOT/profiles/reference/converter-wide-index.callgrind" \
    "$ROOT/profiles/candidate/converter-wide-index.callgrind" "$RESULTS/instructions.csv" <<'PY'
from pathlib import Path
import sys

def instructions(path):
    rows = [line.split()[1] for line in Path(path).read_text().splitlines()
            if line.startswith("summary:")]
    if len(rows) != 1:
        raise SystemExit(f"expected one Callgrind summary in {path}")
    return int(rows[0])

reference, candidate = map(instructions, sys.argv[1:3])
delta = (candidate - reference) * 100.0 / reference
Path(sys.argv[3]).write_text(
    "measurement_base,reference_ir,candidate_ir,delta_pct,output_identical\n"
    f"374b037e7c8fba7097e0b86b05be7956ca6b5487,{reference},{candidate},{delta:.6f},yes\n"
)
if delta > -10.0:
    raise SystemExit(f"focused instruction improvement {delta:.6f}% does not meet 10% gate")
PY

sha256sum "$RESULTS/instructions.csv" "$RESULTS/provenance.txt" \
    "$RESULTS/provenance.sha256" "$RESULTS/edge-reference.out" \
    "$RESULTS/edge-candidate.out" "$RESULTS/converter-reference.out" \
    "$RESULTS/converter-candidate.out" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
