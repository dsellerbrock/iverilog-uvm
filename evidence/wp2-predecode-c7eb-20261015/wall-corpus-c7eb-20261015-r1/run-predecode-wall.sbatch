#!/usr/bin/env bash
#SBATCH --job-name=a5-pd-wall3
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-wall-c7eb-20261015-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-wall-c7eb-20261015-r1/logs/%x-%j.out

set -Eeuo pipefail
RUN_ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-wall-c7eb-20261015-r1
SOURCE_TEMPLATE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/candidate/source
REF=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build/reference/install
CAND=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/build/candidate/install
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
RESULTS=$RUN_ROOT/results
mkdir -p "$RUN_ROOT/logs" "$RESULTS" "$RUN_ROOT/source/benchmarks" "$RUN_ROOT/submit"
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
RUNNER=$RUN_ROOT/source/benchmarks/sim-hotspots/run_json.py
test -x "$REF/bin/vvp" && test -x "$CAND/bin/vvp" && test -x "$REF/bin/iverilog" && test -x "$REF/bin/iverilog-vpi"
grep -qx "measurement_base=$BASE" /home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/input-manifest.txt
{
    printf 'measurement_base=%s\nruns=3\n' "$BASE"
    sha256sum "$REF/bin/vvp" "$CAND/bin/vvp" "$REF/bin/iverilog" "$REF/bin/iverilog-vpi" "$RUNNER"
} > "$RESULTS/provenance.txt"
export PATH="$REF/bin:$PATH"
export IVERILOG="$REF/bin/iverilog"
export IVERILOG_VPI="$REF/bin/iverilog-vpi"
export UVM_DPI="$REF/lib/ivl/uvm_dpi.vpi"
python3 "$RUNNER" "$REF/bin/vvp" "$CAND/bin/vvp" 3 > "$RESULTS/sim-hotspots-wall.json" 2> "$RESULTS/runner.stderr"
python3 - "$RESULTS/sim-hotspots-wall.json" "$RESULTS/wall-summary.csv" "$RESULTS/status.txt" <<'PY'
import csv
import json
import sys
from pathlib import Path

report, csv_path, status_path = map(Path, sys.argv[1:])
data = json.loads(report.read_text())
rows = []
for name, item in data["benchmarks"].items():
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"output mismatch or benchmark error: {name}: {item}")
    ref = item["summary"]["reference"]["wall_seconds"]
    cand = item["summary"]["candidate"]["wall_seconds"]
    speedup = ref["median"] / cand["median"] if cand["median"] else None
    rows.append((name, f'{ref["median"]:.6f}', f'{ref["spread_pct"]:.6f}',
                 f'{cand["median"]:.6f}', f'{cand["spread_pct"]:.6f}',
                 f'{speedup:.6f}' if speedup is not None else ""))
if len(rows) != 18 or data.get("runs") != 3:
    raise SystemExit(f"expected 18 workloads and 3 runs, got {len(rows)} and {data.get('runs')}")
with csv_path.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("benchmark", "reference_median_s", "reference_spread_pct",
                     "candidate_median_s", "candidate_spread_pct", "ref_over_candidate"))
    writer.writerows(rows)
status_path.write_text("workloads=18\nruns_per_side=3\nall_outputs_identical=yes\nwall_spread_is_supporting_only=yes\n")
PY
(cd "$RESULTS" && find . -type f ! -name SHA256SUMS ! -name DONE -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
