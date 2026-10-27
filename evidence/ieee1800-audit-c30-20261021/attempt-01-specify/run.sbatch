#!/usr/bin/env bash
#SBATCH --job-name=a3-c30-specify
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c30-20261021-01/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c30-20261021-01
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
  for mode in specify default; do
    output="$run_dir/build/p30-specify-$edition-$mode.vvp"
    args=()
    if [ "$mode" = specify ]; then args=(-gspecify); fi
    if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" "${args[@]}" -o "$output" p30_specify.sv >"$run_dir/logs/p30-specify-$edition-$mode.compile.stdout" 2>"$run_dir/logs/p30-specify-$edition-$mode.compile.stderr"; then
      printf 'edition=%s mode=%s compile_exit=0\n' "$edition" "$mode"
    else
      rc=$?
      printf 'edition=%s mode=%s compile_exit=%s\n' "$edition" "$mode" "$rc"
      cat "$run_dir/logs/p30-specify-$edition-$mode.compile.stderr"
      status=1
      continue
    fi
    if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" >"$run_dir/logs/p30-specify-$edition-$mode.run.stdout" 2>"$run_dir/logs/p30-specify-$edition-$mode.run.stderr"; then
      printf 'edition=%s mode=%s run_exit=0\n' "$edition" "$mode"
    else
      rc=$?
      printf 'edition=%s mode=%s run_exit=%s\n' "$edition" "$mode" "$rc"
      status=1
    fi
    cat "$run_dir/logs/p30-specify-$edition-$mode.run.stdout"
    cat "$run_dir/logs/p30-specify-$edition-$mode.run.stderr"
  done
done
exit "$status"
