#!/usr/bin/env bash
#SBATCH --job-name=a3-c24-ports
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
set -euo pipefail
run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-003
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"
printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum p24_03_2_program_port_reactive.sv
for edition in 2017 2023; do
  timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/iverilog" "-g$edition" -o "$run_dir/build/program-ports-$edition.vvp" p24_03_2_program_port_reactive.sv >"$run_dir/logs/compile-$edition.stdout" 2>"$run_dir/logs/compile-$edition.stderr"
  timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/vvp" "$run_dir/build/program-ports-$edition.vvp" >"$run_dir/logs/run-$edition.stdout" 2>"$run_dir/logs/run-$edition.stderr"
  grep -Fqx 'dw2=0' "$run_dir/logs/run-$edition.stdout"
  grep -Fqx 'dw2=1' "$run_dir/logs/run-$edition.stdout"
  grep -Fqx 'PASS program_port_reactive' "$run_dir/logs/run-$edition.stdout"
  echo "edition=$edition result=PASS"
done
