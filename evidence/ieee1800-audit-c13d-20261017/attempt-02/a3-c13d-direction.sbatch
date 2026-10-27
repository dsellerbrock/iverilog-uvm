#!/usr/bin/env bash
#SBATCH --job-name=a3-c13d-dir
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13d-20261017-attempt02/logs/%x-%j.out

set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c13d-20261017-attempt02
IVL=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install/bin/vvp
mkdir -p "$RUN/logs" "$RUN/build"

{
  echo "host=$(hostname)"
  date -Is
  echo "toolchain=$($IVL -V 2>&1 | sed -n '1p')"
  sha256sum "$IVL" "$VVP"
  echo "test_source=$(sha256sum "$RUN/inputs/p13_03_tasks.sv")"
  echo "compile_timeout=60s run_timeout=30s"
} > "$RUN/logs/results.txt"

for edition in 2017 2023; do
  out="$RUN/build/p13_03_tasks-$edition.vvp"
  echo "=== -g$edition ===" >> "$RUN/logs/results.txt"
  if timeout -k 2s 60s "$IVL" "-g$edition" -o "$out" "$RUN/inputs/p13_03_tasks.sv" \
      > "$RUN/logs/compile-$edition.log" 2>&1; then
    echo "compile_rc=0" >> "$RUN/logs/results.txt"
  else
    rc=$?
    echo "compile_rc=$rc" >> "$RUN/logs/results.txt"
    cat "$RUN/logs/compile-$edition.log" >> "$RUN/logs/results.txt"
    continue
  fi
  if timeout -k 2s 30s "$VVP" "$out" > "$RUN/logs/run-$edition.log" 2>&1; then
    echo "run_rc=0" >> "$RUN/logs/results.txt"
  else
    rc=$?
    echo "run_rc=$rc" >> "$RUN/logs/results.txt"
  fi
  cat "$RUN/logs/run-$edition.log" >> "$RUN/logs/results.txt"
done

if grep -q 'FAIL\|DONE fails=[^0]' "$RUN/logs/results.txt"; then
  echo 'FINAL_STATUS=1' >> "$RUN/logs/results.txt"
  exit 1
fi
echo 'FINAL_STATUS=0' >> "$RUN/logs/results.txt"
