#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-func-depth
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/c18-func-depth-20261021-01/logs/slurm-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/c18-func-depth-20261021-01
TC=/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb/bin
mkdir -p "$RUN/build" "$RUN/results"
infra=0

for case in g1 g2 g3 g4 g5; do
  source="$RUN/input/p18_05_12_depth_${case}.sv"
  top="p18_05_12_depth_${case}"
  for edition in 2017 2023; do
    work="$RUN/results/$case-$edition"
    mkdir -p "$work"
    log="$RUN/results/$case-$edition.log"
    echo "=== $case -g$edition (60-second timeout) ===" | tee -a "$RUN/results/summary.txt"
    cd "$work"
    /usr/bin/time -f 'elapsed_seconds=%e max_rss_kib=%M' \
      /usr/bin/timeout --signal=TERM --kill-after=2s 60s /bin/bash -c \
        '"$1/iverilog" "$2" -s "$3" -o "$4" "$5" && "$1/vvp" "$4"' \
        _ "$TC" "-g$edition" "$top" "$RUN/build/$top-$edition.vvp" "$source" > "$log" 2>&1
    rc=$?
    cat "$log" | tee -a "$RUN/results/summary.txt"
    echo "exit=$rc" | tee -a "$RUN/results/summary.txt"
    if [[ $rc -eq 124 || $rc -eq 137 ]]; then infra=1; fi
  done
done
echo "infra_timeout=$infra"
exit "$infra"
