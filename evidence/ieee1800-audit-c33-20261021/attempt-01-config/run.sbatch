#!/usr/bin/env bash
#SBATCH --job-name=a3-c33-config
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c33-20261021-01/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c33-20261021-01
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"

printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum ./*.sv
sha256sum "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"

for edition in 2017 2023; do
  for root in cfg top; do
    output="$run_dir/build/p33-$edition-$root.vvp"
    if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -s "$root" -o "$output" p33_cfg.sv >"$run_dir/logs/p33-$edition-$root.compile.stdout" 2>"$run_dir/logs/p33-$edition-$root.compile.stderr"; then
      printf 'edition=%s root=%s compile_exit=0\n' "$edition" "$root"
      if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" >"$run_dir/logs/p33-$edition-$root.run.stdout" 2>"$run_dir/logs/p33-$edition-$root.run.stderr"; then
        printf 'edition=%s root=%s run_exit=0\n' "$edition" "$root"
      else
        rc=$?
        printf 'edition=%s root=%s run_exit=%s\n' "$edition" "$root" "$rc"
      fi
    else
      rc=$?
      printf 'edition=%s root=%s compile_exit=%s\n' "$edition" "$root" "$rc"
    fi
  done
done
exit 0
