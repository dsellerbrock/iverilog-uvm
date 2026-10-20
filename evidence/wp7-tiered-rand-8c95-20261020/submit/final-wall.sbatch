#!/usr/bin/env bash
#SBATCH --job-name=a5-wp7-final-wall
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=3G
#SBATCH --time=00:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-final-wall-rerun-20261020
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-final-wall-rerun-20261020/logs/%x-%j.out

set -Eeuo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-final-wall-rerun-20261020
PRIOR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp7-tiered-rand-8c95-20261020
BASE=8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1
REF=$PRIOR/install/reference
CAND=$PRIOR/install/candidate
SOURCE=$PRIOR/source/candidate
RESULTS=$RUN/results
LOGS=$RUN/logs
FIXTURE=$RUN/input/randomize_t0_disabled.sv

mkdir -p "$RESULTS" "$LOGS"
finish() {
    rc=$?
    trap - EXIT
    printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
    if (( rc == 0 )); then touch "$RESULTS/SUCCESS"; fi
    touch "$RESULTS/DONE"
    exit "$rc"
}
trap finish EXIT

test "$(git -C "$SOURCE" rev-parse HEAD)" = "$BASE"
test -s "$FIXTURE"
for spec in "reference:$REF" "candidate:$CAND"; do
    side=${spec%%:*}
    install=${spec#*:}
    test -x "$install/bin/iverilog" && test -x "$install/bin/vvp"
    expected=$(awk '$2 ~ /\/bin\/vvp$/ {print $1; exit}' \
        "$PRIOR/results/binaries-$side.sha256")
    actual=$(sha256sum "$install/bin/vvp" | awk '{print $1}')
    test "$actual" = "$expected"
    expected=$(awk '$2 ~ /\/bin\/iverilog$/ {print $1; exit}' \
        "$PRIOR/results/binaries-$side.sha256")
    actual=$(sha256sum "$install/bin/iverilog" | awk '{print $1}')
    test "$actual" = "$expected"
    "$install/bin/iverilog" -g2017 -s main -o "$RUN/build-$side.vvp" \
        "$FIXTURE" > "$LOGS/compile-$side.log" 2>&1
done

CPU=$(awk '/Cpus_allowed_list:/ {split($2, a, /[-,]/); print a[1]}' /proc/self/status)
printf 'base=%s\ncpu=%s\ncpus_per_task=1\nreference_vvp=%s\ncandidate_vvp=%s\n' \
    "$BASE" "$CPU" "$(sha256sum "$REF/bin/vvp" | awk '{print $1}')" \
    "$(sha256sum "$CAND/bin/vvp" | awk '{print $1}')" > "$RESULTS/provenance.txt"

python3 - "$RUN" "$CPU" "$REF/bin/vvp" "$CAND/bin/vvp" <<'PY'
import subprocess
import sys
import time
from pathlib import Path

run, cpu, reference, candidate = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
results = run / "results"
for sample in ("01", "02", "03"):
    outputs = {}
    for side, executable in (("reference", reference), ("candidate", candidate)):
        output = results / f"{sample}-{side}.out"
        error = results / f"{sample}-{side}.err"
        start = time.perf_counter_ns()
        with output.open("wb") as stdout, error.open("wb") as stderr:
            subprocess.run(["taskset", "-c", cpu, executable, "-n",
                            str(run / f"build-{side}.vvp")],
                           stdout=stdout, stderr=stderr, check=True)
        elapsed = (time.perf_counter_ns() - start) / 1_000_000_000
        if elapsed <= 0:
            raise SystemExit(f"non-positive elapsed time for {sample}-{side}")
        (results / f"{sample}-{side}.seconds").write_text(f"{elapsed:.9f}\n")
        outputs[side] = (output, error)
    for suffix, index in (("out", 0), ("err", 1)):
        if outputs["reference"][index].read_bytes() != \
                outputs["candidate"][index].read_bytes():
            raise SystemExit(f"output mismatch for sample {sample} ({suffix})")
PY
for side in reference candidate; do
    for sample in 02 03; do
        cmp "$RESULTS/01-$side.out" "$RESULTS/$sample-$side.out"
        cmp "$RESULTS/01-$side.err" "$RESULTS/$sample-$side.err"
    done
done

python3 - "$RESULTS" "$BASE" <<'PY'
import csv
import statistics
import sys
from pathlib import Path

results, base = Path(sys.argv[1]), sys.argv[2]
times = {
    side: [float((results / f"{sample}-{side}.seconds").read_text())
           for sample in ("01", "02", "03")]
    for side in ("reference", "candidate")
}
medians = {side: statistics.median(values) for side, values in times.items()}
spreads = {side: (max(values) - min(values)) / medians[side] * 100
           for side, values in times.items()}
with (results / "wall.csv").open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("workload", "measurement_base", "reference_median_s",
                     "reference_spread_pct", "candidate_median_s",
                     "candidate_spread_pct", "speedup", "outputs_identical"))
    writer.writerow(("randomize_t0_disabled", base, f"{medians['reference']:.6f}",
                     f"{spreads['reference']:.3f}", f"{medians['candidate']:.6f}",
                     f"{spreads['candidate']:.3f}",
                     f"{medians['reference']/medians['candidate']:.4f}", "yes"))
PY

(cd "$RUN" && find results -type f ! -name SHA256SUMS -print0 \
    | sort -z | xargs -0 sha256sum) > "$RESULTS/SHA256SUMS"
