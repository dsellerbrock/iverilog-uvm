#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp3-fst-cg
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-fst-cg1
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-fst-cg1/logs/%x-%j.out

set -euo pipefail

RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-fst-cg1
BUILD=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build
SOURCE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/incoming/reference/source/benchmarks/sim-hotspots/waveform.sv
TOOLS=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/tools/root
RESULTS="$RUN_DIR/results"

mkdir -p "$RESULTS" "$RUN_DIR/logs" "$RESULTS/callgrind"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

VALGRIND="$TOOLS/usr/bin/valgrind"
export VALGRIND_LIB="$TOOLS/usr/libexec/valgrind"
IVERILOG="$BUILD/reference/install/bin/iverilog"
REF_VVP="$BUILD/reference/install/bin/vvp"
CAND_VVP="$BUILD/candidate/install/bin/vvp"
"$IVERILOG" -g2012 -o "$RUN_DIR/waveform.vvp" "$SOURCE"

for side in reference candidate; do
  mkdir -p "$RESULTS/$side"
  runtime="$REF_VVP"
  [ "$side" = reference ] || runtime="$CAND_VVP"
  set +e
  (cd "$RESULTS/$side" && LC_ALL=C /usr/bin/time -f '%M' \
    -o "$RESULTS/$side.max-rss-kb" -- "$VALGRIND" --quiet \
    --tool=callgrind \
    --callgrind-out-file="$RESULTS/callgrind/$side.callgrind" \
    --log-file="$RESULTS/callgrind/$side.valgrind.log" \
    "$runtime" -n "$RUN_DIR/waveform.vvp" +use_fst -fst -no-date \
    > stdout.bin 2> stderr.txt)
  rc=$?
  set -e
  printf '%s\n' "$rc" > "$RESULTS/$side.exit-code"
done

for side in reference candidate; do
  test "$(cat "$RESULTS/$side.exit-code")" -eq 0
done
cmp "$RESULTS/reference/stdout.bin" "$RESULTS/candidate/stdout.bin"
cmp "$RESULTS/reference/stderr.txt" "$RESULTS/candidate/stderr.txt"
diff -r --exclude=exit-code --exclude=max-rss-kb \
  "$RESULTS/reference" "$RESULTS/candidate"
python3 - "$RESULTS/callgrind" "$RUN_DIR/instruction-counts.csv" <<'PY'
import csv
import sys
from pathlib import Path

profile_dir, csv_path = map(Path, sys.argv[1:])

def instructions(path):
    summaries = [line.split()[1] for line in path.read_text().splitlines()
                 if line.startswith("summary:")]
    if len(summaries) != 1:
        raise RuntimeError(f"expected one Callgrind summary in {path}")
    return int(summaries[0])

ref = instructions(profile_dir / "reference.callgrind")
cand = instructions(profile_dir / "candidate.callgrind")
with csv_path.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("benchmark", "reference_ir", "candidate_ir", "delta_ir", "delta_pct"))
    writer.writerow(("waveform_fst", ref, cand, cand-ref, f"{(cand-ref)*100/ref:.6f}"))
PY
printf 'measurement_base=%s\n' c7ebca768c21c251d9c165c9aff0e363768030b1 \
  > "$RUN_DIR/measurement-base.txt"
