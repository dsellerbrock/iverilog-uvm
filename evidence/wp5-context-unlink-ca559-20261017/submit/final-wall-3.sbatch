#!/usr/bin/env bash
#SBATCH --job-name=a5-wp5-final-wall
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp5-context-unlink-wall-ca559-20261017
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp5-context-unlink-wall-ca559-20261017/logs/%x-%j.out

set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp5-context-unlink-wall-ca559-20261017
BASE=ca559fd97b19bd6a56cc10f0faf8583b4077975f
SOURCE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp5-context-unlink-gates-ca559-20261017/source/candidate
REF=/home/dsell/toolchains/iverilog-uvm-ca559fd97b19bd6a56cc10f0faf8583b4077975f-m3-profile
CAND=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp5-context-unlink-gates-ca559-20261017/install/candidate
RESULTS=$RUN/results
RUNNER=$SOURCE/benchmarks/sim-hotspots/run_json_m3_final.py

mkdir -p "$RUN/logs" "$RUN/results"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
test -x "$REF/bin/vvp" && test -x "$CAND/bin/vvp"
test -x "$REF/bin/iverilog" && test -x "$REF/bin/iverilog-vpi"
test -s "$REF/lib/ivl/uvm_dpi.vpi"
cp "$RUN/input/run_json_callgrind.py" "$RUNNER"
{
  hostname
  uname -a
  printf 'measurement_base=%s\nruns=3\n' "$BASE"
  git -C "$SOURCE" status --short
  "$REF/bin/vvp" -V | head -n 1
  "$CAND/bin/vvp" -V | head -n 1
  sha256sum "$REF/bin/vvp" "$CAND/bin/vvp" "$REF/bin/iverilog" \
    "$REF/bin/iverilog-vpi" "$REF/lib/ivl/uvm_dpi.vpi" "$RUNNER"
} > "$RUN/environment.txt"

PATH="$REF/bin:$PATH" \
IVERILOG="$REF/bin/iverilog" \
IVERILOG_VPI="$REF/bin/iverilog-vpi" \
UVM_DPI="$REF/lib/ivl/uvm_dpi.vpi" \
  python3 "$RUNNER" "$REF/bin/vvp" "$CAND/bin/vvp" 3 > "$RESULTS/wall-3.json"

python3 - "$RESULTS/wall-3.json" "$RESULTS/wall-summary.csv" <<'PY'
import csv
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
rows = []
for name, item in sorted(data["benchmarks"].items()):
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"output mismatch or benchmark error: {name}: {item}")
    reference = item["summary"]["reference"]["wall_seconds"]
    candidate = item["summary"]["candidate"]["wall_seconds"]
    speedup = reference["median"] / candidate["median"]
    rows.append((name, reference["median"], reference["spread_pct"],
                 candidate["median"], candidate["spread_pct"], speedup))
if data.get("runs") != 3 or len(rows) != 18:
    raise SystemExit(f"expected 18 workloads and 3 runs; got {len(rows)} and {data.get('runs')}")
with Path(sys.argv[2]).open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("benchmark", "reference_median_s", "reference_spread_pct",
                     "candidate_median_s", "candidate_spread_pct", "ref_over_candidate"))
    writer.writerows(rows)
PY

printf 'measurement_base=%s\nruns_per_side=3\nworkloads=18\nall_outputs_identical=yes\n' "$BASE" > "$RESULTS/status.txt"
(cd "$RESULTS" && sha256sum wall-3.json wall-summary.csv status.txt > SHA256SUMS)
