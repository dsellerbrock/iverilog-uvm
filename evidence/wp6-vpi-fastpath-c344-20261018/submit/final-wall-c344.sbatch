#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-c344-wall
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r3
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r3/logs/a5-wp6-c344-wall-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-c344-20261018-r3
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
REF_INSTALL=$ROOT/install/reference
CAND_INSTALL=$ROOT/install/candidate
RUNNER=$ROOT/source/candidate/benchmarks/sim-hotspots/run_json_m3_final.py
RESULTS=$ROOT/final-wall-c344-r2
mkdir -p "$RESULTS" "$ROOT/logs"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$ROOT/gates-c344/job-exit-code")" = 0
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
cp "$ROOT/input/run_json_callgrind.py" "$RUNNER"
{
  hostname
  uname -a
  printf 'measurement_base=%s\nruns_per_side=3\n' "$BASE"
  cat "$ROOT/input/source-provenance.txt"
  sha256sum "$RUNNER" "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" \
    "$REF_INSTALL/bin/iverilog" "$CAND_INSTALL/bin/iverilog"
} > "$RESULTS/environment.txt"

PATH="$REF_INSTALL/bin:$PATH" \
IVERILOG="$REF_INSTALL/bin/iverilog" \
IVERILOG_VPI="$REF_INSTALL/bin/iverilog-vpi" \
UVM_DPI="$REF_INSTALL/lib/ivl/uvm_dpi.vpi" \
  python3 "$RUNNER" "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" 3 > "$RESULTS/wall-3.json"

python3 - "$RESULTS/wall-3.json" "$RESULTS/wall-summary.csv" <<'PY'
import csv, json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
rows = []
for name, item in sorted(data["benchmarks"].items()):
    if item.get("status") != "ok" or item.get("identical_all_runs") is not True:
        raise SystemExit(f"output mismatch or benchmark error: {name}: {item}")
    reference = item["summary"]["reference"]["wall_seconds"]
    candidate = item["summary"]["candidate"]["wall_seconds"]
    rows.append((name, reference["median"], reference["spread_pct"],
                 candidate["median"], candidate["spread_pct"],
                 reference["median"] / candidate["median"]))
if data.get("runs") != 3 or len(rows) != 18:
    raise SystemExit(f"expected 18 workloads and 3 runs; got {len(rows)} and {data.get('runs')}")
with Path(sys.argv[2]).open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("benchmark", "reference_median_s", "reference_spread_pct",
                     "candidate_median_s", "candidate_spread_pct", "ref_over_candidate"))
    writer.writerows(rows)
PY

printf 'measurement_base=%s\nruns_per_side=3\nworkloads=18\nall_outputs_identical=yes\n' "$BASE" > "$RESULTS/status.txt"
sha256sum "$RESULTS/environment.txt" "$RESULTS/wall-3.json" \
  "$RESULTS/wall-summary.csv" "$RESULTS/status.txt" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
