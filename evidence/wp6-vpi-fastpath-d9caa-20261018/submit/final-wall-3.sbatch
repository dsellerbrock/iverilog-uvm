#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-d9caa-wall
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=04:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-d9caa-20261018-r2
BASE=d9caaaea5b410ed14e7ca14be828fc2f2c9fea44
REF_INSTALL=/home/dsell/toolchains/iverilog-uvm-d9caaaea5b410ed14e7ca14be828fc2f2c9fea44-a5-wp6-r2
CAND_INSTALL=$ROOT/install/candidate
INPUT=$ROOT/input
SOURCE=$ROOT/source/wall
RESULTS=$ROOT/final-wall
mkdir -p "$RESULTS" "$ROOT/logs" "$(dirname "$SOURCE")"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$ROOT/gates/job-exit-code")" = 0
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
(
  cd "$INPUT"
  sha256sum --check source-inputs.sha256
)
mkdir -p "$SOURCE/third_party/uvm/2020.2.0" "$SOURCE/third_party/uvm/2020.3.0" "$SOURCE/uvm-core"
tar -xzf "$INPUT/iverilog-uvm-d9caa-sourceonly.tar.gz" -C "$SOURCE"
tar -xzf "$INPUT/uvm-2020.2.0.tar.gz" -C "$SOURCE/third_party/uvm/2020.2.0"
tar -xzf "$INPUT/uvm-2020.3.0.tar.gz" -C "$SOURCE/third_party/uvm/2020.3.0"
tar -xzf "$INPUT/uvm-core-78c0654.tar.gz" -C "$SOURCE/uvm-core"
patch --dry-run -p1 -d "$SOURCE" < "$INPUT/candidate.patch" > "$RESULTS/patch-check.log"
patch -p1 -d "$SOURCE" < "$INPUT/candidate.patch" > "$RESULTS/patch.log"

RUNNER=$SOURCE/benchmarks/sim-hotspots/run_json_m3_final.py
cp "$INPUT/run_json_callgrind.py" "$RUNNER"
{
  hostname
  uname -a
  printf 'measurement_base=%s\nruns_per_side=3\n' "$BASE"
  cat "$INPUT/source-provenance.txt"
  "$REF_INSTALL/bin/vvp" -V | head -n 1
  "$CAND_INSTALL/bin/vvp" -V | head -n 1
  sha256sum "$INPUT/candidate.patch" "$REF_INSTALL/bin/vvp" "$CAND_INSTALL/bin/vvp" \
    "$REF_INSTALL/bin/iverilog" "$CAND_INSTALL/bin/iverilog" "$INPUT/run_json_callgrind.py"
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
sha256sum "$RESULTS/environment.txt" "$RESULTS/wall-3.json" "$RESULTS/wall-summary.csv" \
  "$RESULTS/status.txt" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
