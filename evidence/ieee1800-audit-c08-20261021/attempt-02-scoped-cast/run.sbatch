#!/usr/bin/env bash
#SBATCH --job-name=a3-c08-cast
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:15:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/c08-scoped-cast-20261021-01/logs/slurm-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/c08-scoped-cast-20261021-01
TC=/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb/bin
mkdir -p "$RUN/build" "$RUN/results"
infra=0

for src in "$RUN"/input/p08_05_scoped_cast_k*.sv; do
  name=$(basename "$src" .sv)
  for edition in 2017 2023; do
    work="$RUN/results/$name-$edition"
    mkdir -p "$work"
    log="$RUN/results/$name-$edition.log"
    echo "=== $name -g$edition (60-second timeout) ===" | tee -a "$RUN/results/summary.txt"
    cd "$work"
    /usr/bin/time -f 'elapsed_seconds=%e max_rss_kib=%M' \
      /usr/bin/timeout --signal=TERM --kill-after=2s 60s /bin/bash -c \
        '"$1/iverilog" "$2" -s top -o "$3" "$4" && "$1/vvp" "$3"' \
        _ "$TC" "-g$edition" "$work/a.vvp" "$src" > "$log" 2>&1
    rc=$?
    cat "$log" | tee -a "$RUN/results/summary.txt"
    echo "exit=$rc" | tee -a "$RUN/results/summary.txt"
    if [[ $rc -eq 124 || $rc -eq 137 ]]; then infra=1; fi
  done
done
echo "infra_timeout=$infra"
exit "$infra"
