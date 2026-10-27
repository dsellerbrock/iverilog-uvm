#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-unif-h1000
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=128M
#SBATCH --time=00:12:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/c18-uniform-heap-20261021-02/logs/slurm-%j.out

set -uo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/c18-uniform-heap-20261021-02
TC=/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb/bin
mkdir -p "$RUN/build" "$RUN/results"
timed_out=0

for edition in 2017 2023; do
  source="$RUN/input/p18_uniform_heap.sv"
  executable="$RUN/build/p18_uniform_heap-$edition.vvp"
  compile_log="$RUN/results/compile-$edition.log"
  run_log="$RUN/results/run-$edition.log"
  echo "=== compile -g$edition (300-second timeout; n=1000) ===" | tee -a "$RUN/results/summary.txt"
  /usr/bin/timeout --signal=TERM --kill-after=2s 300s \
    "$TC/iverilog" "-g$edition" -s p18_uniform_heap -o "$executable" "$source" > "$compile_log" 2>&1
  compile_rc=$?
  cat "$compile_log" | tee -a "$RUN/results/summary.txt"
  echo "compile_exit=$compile_rc" | tee -a "$RUN/results/summary.txt"
  if [[ $compile_rc -eq 124 || $compile_rc -eq 137 ]]; then timed_out=1; continue; fi
  if [[ $compile_rc -ne 0 ]]; then continue; fi

  echo "=== run -g$edition (300-second timeout; n=1000) ===" | tee -a "$RUN/results/summary.txt"
  cd "$RUN/results"
  /usr/bin/time -f 'elapsed_seconds=%e max_rss_kib=%M' \
    /usr/bin/timeout --signal=TERM --kill-after=2s 300s \
      "$TC/vvp" "$executable" > "$run_log" 2>&1
  run_rc=$?
  cat "$run_log" | tee -a "$RUN/results/summary.txt"
  echo "run_exit=$run_rc" | tee -a "$RUN/results/summary.txt"
  if [[ $run_rc -eq 124 || $run_rc -eq 137 ]]; then timed_out=1; fi
done
echo "timed_out=$timed_out"
exit 0
