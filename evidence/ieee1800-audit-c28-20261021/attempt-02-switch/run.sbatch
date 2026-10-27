#!/usr/bin/env bash
#SBATCH --job-name=a3-c28-switch
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c28-20261021-02/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c28-20261021-02
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
  for name in p28_switch p28_trireg_decay; do
    output="$run_dir/build/$name-$edition.vvp"
    if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -o "$output" "$name.sv" >"$run_dir/logs/$name-$edition.compile.stdout" 2>"$run_dir/logs/$name-$edition.compile.stderr"; then
      printf '%s edition=%s compile_exit=0\n' "$name" "$edition"
    else
      rc=$?
      printf '%s edition=%s compile_exit=%s\n' "$name" "$edition" "$rc"
      cat "$run_dir/logs/$name-$edition.compile.stderr"
      status=1
      continue
    fi
    if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" >"$run_dir/logs/$name-$edition.run.stdout" 2>"$run_dir/logs/$name-$edition.run.stderr"; then
      printf '%s edition=%s run_exit=0\n' "$name" "$edition"
    else
      rc=$?
      printf '%s edition=%s run_exit=%s\n' "$name" "$edition" "$rc"
      status=1
    fi
    cat "$run_dir/logs/$name-$edition.run.stdout"
    cat "$run_dir/logs/$name-$edition.run.stderr"
  done
done
exit "$status"
