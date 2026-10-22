#!/usr/bin/env bash
#SBATCH --job-name=a3-c08-shallow
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/c08-shallow-20261021-01/logs/slurm-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/c08-shallow-20261021-01
TC=/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb/bin
mkdir -p "$RUN/build" "$RUN/results"
overall=0

for src in "$RUN"/input/p08_12_shallow_s*.sv; do
  name=$(basename "$src" .sv)
  for edition in 2017 2023; do
    out="$RUN/build/$name-$edition.vvp"
    result="$RUN/results/$name-$edition.txt"
    echo "=== $name -g$edition (60-second test timeout) ===" | tee -a "$RUN/results/summary.txt"
    /usr/bin/timeout --signal=TERM --kill-after=2s 60s /bin/bash -c \
      '"$1/iverilog" "$2" -s top -o "$3" "$4" && "$1/vvp" "$3"' \
      _ "$TC" "-g$edition" "$out" "$src" > "$result" 2>&1
    rc=$?
    cat "$result" | tee -a "$RUN/results/summary.txt"
    echo "exit=$rc" | tee -a "$RUN/results/summary.txt"
    if [[ $rc -ne 0 ]]; then overall=1; fi
  done
done
echo "overall=$overall"
exit "$overall"
