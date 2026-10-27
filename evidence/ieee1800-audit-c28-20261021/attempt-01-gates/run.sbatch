#!/usr/bin/env bash
#SBATCH --job-name=a3-c28-gates
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c28-20261021-01
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"

printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum ./*.sv
sha256sum "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"

status=0
for edition in 2017 2023; do
  output="$run_dir/build/p28-gates-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -o "$output" p28_gates.sv >"$run_dir/logs/p28-gates-$edition.compile.stdout" 2>"$run_dir/logs/p28-gates-$edition.compile.stderr"; then
    printf 'edition=%s compile_exit=0\n' "$edition"
  else
    rc=$?
    printf 'edition=%s compile_exit=%s\n' "$edition" "$rc"
    cat "$run_dir/logs/p28-gates-$edition.compile.stderr"
    status=1
    continue
  fi
  if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" >"$run_dir/logs/p28-gates-$edition.run.stdout" 2>"$run_dir/logs/p28-gates-$edition.run.stderr"; then
    printf 'edition=%s run_exit=0\n' "$edition"
  else
    rc=$?
    printf 'edition=%s run_exit=%s\n' "$edition" "$rc"
    status=1
  fi
  cat "$run_dir/logs/p28-gates-$edition.run.stdout"
  cat "$run_dir/logs/p28-gates-$edition.run.stderr"
done
exit "$status"
