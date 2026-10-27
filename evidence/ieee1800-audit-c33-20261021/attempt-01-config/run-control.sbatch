#!/usr/bin/env bash
#SBATCH --job-name=a3-c33-control
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c33-20261021-02/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c33-20261021-02
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"

printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum p33_cfg_control.sv "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"
failed=0
for edition in 2017 2023; do
  output="$run_dir/build/p33-control-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -s top -o "$output" p33_cfg_control.sv >"$run_dir/logs/p33-control-$edition.compile.stdout" 2>"$run_dir/logs/p33-control-$edition.compile.stderr"; then
    if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" >"$run_dir/logs/p33-control-$edition.run.stdout" 2>"$run_dir/logs/p33-control-$edition.run.stderr"; then
      printf 'edition=%s compile_exit=0 run_exit=0 output=%s\n' "$edition" "$(tr '\n' ' ' <"$run_dir/logs/p33-control-$edition.run.stdout")"
    else
      rc=$?
      printf 'edition=%s compile_exit=0 run_exit=%s\n' "$edition" "$rc"
      failed=1
    fi
  else
    rc=$?
    printf 'edition=%s compile_exit=%s\n' "$edition" "$rc"
    failed=1
  fi
done
exit "$failed"
