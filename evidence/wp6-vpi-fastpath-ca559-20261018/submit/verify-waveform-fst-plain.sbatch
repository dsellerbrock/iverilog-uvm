#!/usr/bin/env bash
#SBATCH --job-name=a5-wp6-fst-oracle
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-ca559-20261018-r1/submit
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-ca559-20261018-r1/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp6-vpi-fastpath-ca559-20261018-r1
BASE=ca559fd97b19bd6a56cc10f0faf8583b4077975f
SOURCE=$ROOT/source/candidate
REF_INSTALL=/home/dsell/toolchains/iverilog-uvm-ca559fd97b19bd6a56cc10f0faf8583b4077975f-m3-profile
CAND_INSTALL=$ROOT/install/candidate
RESULTS=$ROOT/corpus-screen/waveform-fst-plain-oracle
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
PROGRAM=$RESULTS/waveform_fst.vvp
"$REF_INSTALL/bin/iverilog" -g2012 -o "$PROGRAM" "$SOURCE/benchmarks/sim-hotspots/waveform.sv"
cpu=$(python3 -c 'import os; print(min(os.sched_getaffinity(0)))')
for run in 1 2 3; do
  if (( run % 2 )); then order=(reference candidate); else order=(candidate reference); fi
  for side in "${order[@]}"; do
    case "$side" in
      reference) runtime=$REF_INSTALL/bin/vvp ;;
      candidate) runtime=$CAND_INSTALL/bin/vvp ;;
    esac
    dest=$RESULTS/run-$run-$side
    mkdir -p "$dest"
    (
      cd "$dest"
      /usr/bin/time -f '%e,%M' -o time-rss.csv taskset -c "$cpu" \
        "$runtime" -n "$PROGRAM" +use_fst -fst -no-date > stdout.bin 2>&1
      sha256sum stdout.bin waveform.fst > output-sha256.txt
    )
  done
  cmp "$RESULTS/run-$run-reference/stdout.bin" "$RESULTS/run-$run-candidate/stdout.bin"
  cmp "$RESULTS/run-$run-reference/waveform.fst" "$RESULTS/run-$run-candidate/waveform.fst"
done
printf 'measurement_base=%s\nbenchmark=waveform_fst\nruns=3\ncpu=%s\n' \
  "$BASE" "$cpu" > "$RESULTS/provenance.txt"
find "$RESULTS" -maxdepth 2 -type f \( -name output-sha256.txt -o -name time-rss.csv \) -print0 \
  | sort -z | xargs -0 sha256sum > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
