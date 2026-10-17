#!/usr/bin/env bash
#SBATCH --job-name=a5-pd-corpus-cg
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=06:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-callgrind-c7eb-20261015-r2/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-callgrind-c7eb-20261015-r2/logs/%x-%j.out

set -Eeuo pipefail
RUN_ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-callgrind-c7eb-20261015-r2
SOURCE_TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/candidate/source
REF=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build/reference/install
CAND=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/build/candidate/install
TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp1-debug-tax-0490e2ff-20261015-r3/tools/root
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
RESULTS=$RUN_ROOT/results
PROFILES=$RESULTS/callgrind
mkdir -p "$RUN_ROOT/logs" "$RESULTS" "$PROFILES" "$RUN_ROOT/source/benchmarks" "$RUN_ROOT/submit"
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT
cp -a "$SOURCE_TEMPLATE/benchmarks/sim-hotspots" "$RUN_ROOT/source/benchmarks/"
cp -a "$SOURCE_TEMPLATE/uvm-core" "$RUN_ROOT/source/"
cp "$RUN_ROOT/input/run_json_callgrind.py" "$RUN_ROOT/source/benchmarks/sim-hotspots/"
RUNNER=$RUN_ROOT/source/benchmarks/sim-hotspots/run_json_callgrind.py
VALGRIND=$TOOLS/usr/bin/valgrind
export VALGRIND_LIB=$TOOLS/usr/libexec/valgrind
test -x "$VALGRIND" && test -d "$VALGRIND_LIB"
test -x "$REF/bin/vvp" && test -x "$CAND/bin/vvp" && test -x "$REF/bin/iverilog" && test -x "$REF/bin/iverilog-vpi"
grep -qx "measurement_base=$BASE" /home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/input-manifest.txt
mkdir -p "$RUN_ROOT/wrappers"
make_wrapper() {
    side=$1 runtime=$2 path=$RUN_ROOT/wrappers/callgrind-$1
    cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
name=\$(basename "\$(dirname "\$PWD")")-\$(basename "\$PWD")
exec "$VALGRIND" --quiet --tool=callgrind --fair-sched=yes \\
  --callgrind-out-file="$PROFILES/\$name.callgrind" \\
  --log-file="$PROFILES/\$name.valgrind.log" "$runtime" "\$@"
EOF
    chmod +x "$path"
}
make_wrapper reference "$REF/bin/vvp"
make_wrapper candidate "$CAND/bin/vvp"
{
    printf 'measurement_base=%s\n' "$BASE"
    sha256sum "$REF/bin/vvp" "$CAND/bin/vvp" "$REF/bin/iverilog" "$REF/bin/iverilog-vpi" "$RUNNER"
    sha256sum "$SOURCE_TEMPLATE/vvp/codes.cc" "$SOURCE_TEMPLATE/vvp/codes.h" "$SOURCE_TEMPLATE/vvp/compile.cc" "$SOURCE_TEMPLATE/vvp/vthread.cc"
    "$VALGRIND" --version
} > "$RESULTS/provenance.txt"
export PATH="$REF/bin:$PATH"
export IVERILOG="$REF/bin/iverilog"
export IVERILOG_VPI="$REF/bin/iverilog-vpi"
export UVM_DPI="$REF/lib/ivl/uvm_dpi.vpi"
set +e
python3 "$RUNNER" "$RUN_ROOT/wrappers/callgrind-reference" \
    "$RUN_ROOT/wrappers/callgrind-candidate" 1 > "$RESULTS/sim-hotspots.json" \
    2> "$RESULTS/runner.stderr"
runner_exit=$?
set -e
printf '%s\n' "$runner_exit" > "$RESULTS/runner-exit-code"
test "$runner_exit" -eq 0
python3 - "$RESULTS/sim-hotspots.json" "$PROFILES" "$RESULTS/instruction-counts.csv" "$RESULTS/screen.txt" <<'PY'
import csv
import json
import sys
from pathlib import Path

result_path, profile_dir, csv_path, status_path = map(Path, sys.argv[1:])
data = json.loads(result_path.read_text())
rows = []
all_outputs_identical = True

def instructions(path):
    lines = [line.split()[1] for line in path.read_text().splitlines()
             if line.startswith("summary:")]
    if len(lines) != 1 or int(lines[0]) <= 0:
        raise RuntimeError(f"expected one positive Callgrind summary in {path}")
    return int(lines[0])

for name, item in data["benchmarks"].items():
    output_ok = item.get("status") == "ok" and item.get("identical_all_runs") is True
    all_outputs_identical &= output_ok
    reference = instructions(profile_dir / f"{name}-01-reference.callgrind")
    candidate = instructions(profile_dir / f"{name}-01-candidate.callgrind")
    delta = 100.0 * (candidate - reference) / reference
    rows.append((name, reference, candidate, candidate-reference, f"{delta:.6f}", "yes" if output_ok else "no"))

with csv_path.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("benchmark", "reference_ir", "candidate_ir", "delta_ir", "delta_pct", "output_identical"))
    writer.writerows(rows)
worst = max(float(row[4]) for row in rows)
passed = len(rows) == 18 and all_outputs_identical and worst <= 2.0
status_path.write_text(
    f"benchmark_rows={len(rows)}\nall_outputs_identical={'yes' if all_outputs_identical else 'no'}\n"
    f"worst_instruction_regression_pct={worst:.6f}\nregression_gate_pct=2.0\n"
    f"status={'passed' if passed else 'failed'}\n")
if not passed:
    raise SystemExit(status_path.read_text())
PY
gzip -n "$PROFILES"/*.callgrind
(cd "$RESULTS" && find . -type f ! -name SHA256SUMS ! -name DONE -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
