#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-fst-rerun
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-ca559-20261018-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-ca559-20261018-r1/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-ca559-20261018-r1
BASE=ca559fd97b19bd6a56cc10f0faf8583b4077975f
SOURCE=$ROOT/source/candidate
REF_INSTALL=/home/dsell/toolchains/iverilog-uvm-ca559fd97b19bd6a56cc10f0faf8583b4077975f-m3-profile
CAND_INSTALL=$ROOT/install/candidate
RESULTS=$ROOT/corpus-screen/waveform-fst-isolated
mkdir -p "$RESULTS" "$ROOT/logs"
finish() {
    local rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
test -x "$REF_INSTALL/bin/vvp" && test -x "$CAND_INSTALL/bin/vvp"
test -x "$REF_INSTALL/bin/iverilog" && test -x /usr/bin/valgrind
export VALGRIND_LIB=/usr/libexec/valgrind
PROGRAM=$RESULTS/waveform_fst.vvp
"$REF_INSTALL/bin/iverilog" -g2012 -o "$PROGRAM" "$SOURCE/benchmarks/sim-hotspots/waveform.sv"
mkdir -p "$RESULTS/callgrind"
for side in reference candidate; do
  case "$side" in
    reference) runtime=$REF_INSTALL/bin/vvp ;;
    candidate) runtime=$CAND_INSTALL/bin/vvp ;;
  esac
  mkdir -p "$RESULTS/$side"
  (
    cd "$RESULTS/$side"
    /usr/bin/valgrind --quiet --tool=callgrind --fair-sched=yes \
      --callgrind-out-file="$RESULTS/callgrind/waveform_fst-01-$side.callgrind" \
      --log-file="$RESULTS/callgrind/waveform_fst-01-$side.valgrind.log" \
      "$runtime" -n "$PROGRAM" +use_fst -fst -no-date > stdout.bin 2>&1
    sha256sum stdout.bin waveform.fst > "$RESULTS/$side/output-sha256.txt"
  )
done
cmp "$RESULTS/reference/stdout.bin" "$RESULTS/candidate/stdout.bin"
cmp "$RESULTS/reference/waveform.fst" "$RESULTS/candidate/waveform.fst"
python3 - "$BASE" "$RESULTS/callgrind" "$RESULTS/instruction-counts.csv" <<'PY'
import csv, sys
from pathlib import Path
base, profile_dir, csv_path = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
counts = []
for side in ("reference", "candidate"):
    path = profile_dir / f"waveform_fst-01-{side}.callgrind"
    values = [line.split()[1] for line in path.read_text().splitlines() if line.startswith("summary:")]
    if len(values) != 1:
        raise SystemExit(f"expected one Callgrind summary in {path}")
    counts.append(int(values[0]))
reference, candidate = counts
with csv_path.open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("measurement_base", "benchmark", "reference_ir", "candidate_ir", "delta_ir", "delta_pct", "output_identical"))
    writer.writerow((base, "waveform_fst", reference, candidate, candidate-reference, f"{(candidate-reference)*100.0/reference:.6f}", "yes"))
PY
sha256sum "$RESULTS/instruction-counts.csv" "$RESULTS/reference/output-sha256.txt" \
  "$RESULTS/candidate/output-sha256.txt" > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
