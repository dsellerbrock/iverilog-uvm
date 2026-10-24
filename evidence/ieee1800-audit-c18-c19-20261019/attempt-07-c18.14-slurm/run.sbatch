#!/bin/bash
#SBATCH --job-name=a3-audit-c18-14
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/audit-c18-14-20261019-01/logs/c18.14-%j.out

set -u
run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/audit-c18-14-20261019-01
toolchain=/home/dsell/toolchains/iverilog-a3-main-82023726-679
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
source_file="$run_dir/input/p18_14_stability.sv"
mkdir -p "$run_dir/results"

{
  printf 'Host: '; hostname
  printf 'UTC start: '; date -u '+%Y-%m-%d %H:%M:%S UTC'
  printf 'Source SHA-256: '; sha256sum "$source_file"
  printf 'iverilog SHA-256: '; sha256sum "$iverilog"
  printf 'vvp SHA-256: '; sha256sum "$vvp"
  "$iverilog" -V | head -2
  "$vvp" -V 2>&1 | head -2
  printf 'Commands: timeout 30s iverilog -g2017/-g2023 -s test; timeout 30s vvp -n\n'
} > "$run_dir/results/metadata.txt" 2>&1

rc2017=0
timeout --signal=TERM --kill-after=5s 30s "$iverilog" -g2017 -s test -o "$run_dir/results/p18_14_2017.vvp" "$source_file" > "$run_dir/results/build-2017.log" 2>&1 || rc2017=$?
if [ "$rc2017" -eq 0 ]; then
  timeout --signal=TERM --kill-after=5s 30s "$vvp" -n "$run_dir/results/p18_14_2017.vvp" > "$run_dir/results/run-2017.log" 2>&1 || rc2017=$?
fi

rc2023=0
timeout --signal=TERM --kill-after=5s 30s "$iverilog" -g2023 -s test -o "$run_dir/results/p18_14_2023.vvp" "$source_file" > "$run_dir/results/build-2023.log" 2>&1 || rc2023=$?
if [ "$rc2023" -eq 0 ]; then
  timeout --signal=TERM --kill-after=5s 30s "$vvp" -n "$run_dir/results/p18_14_2023.vvp" > "$run_dir/results/run-2023.log" 2>&1 || rc2023=$?
fi

printf '2017 exit: %s\n2023 exit: %s\n' "$rc2017" "$rc2023" | tee "$run_dir/results/exit-status.txt"
printf 'UTC end: ' >> "$run_dir/results/metadata.txt"
date -u '+%Y-%m-%d %H:%M:%S UTC' >> "$run_dir/results/metadata.txt"
[ "$rc2017" -eq 0 ] && [ "$rc2023" -eq 0 ]
