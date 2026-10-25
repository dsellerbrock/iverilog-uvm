#!/usr/bin/env bash
#SBATCH --job-name=a3-c31-tchk2
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c31-tchk2-20261021-a1/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/A3/c31-tchk2-20261021-a1
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
status=0

mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"
printf 'host=%s\n' "$(hostname)"
printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
printf 'toolchain=%s\n' "$toolchain"
sha256sum ./*.sv "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"

for edition in 2017 2023; do
  output="$run_dir/build/p31-tchk2-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" \
    "-g$edition" -gspecify -o "$output" p31_tchk2.sv \
    >"$run_dir/logs/p31-tchk2-$edition.compile.stdout" \
    2>"$run_dir/logs/p31-tchk2-$edition.compile.stderr"; then
    printf 'edition=%s compile_exit=0\n' "$edition"
  else
    rc=$?
    printf 'edition=%s compile_exit=%s\n' "$edition" "$rc"
    status=1
    continue
  fi
  if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" \
    >"$run_dir/logs/p31-tchk2-$edition.run.stdout" \
    2>"$run_dir/logs/p31-tchk2-$edition.run.stderr"; then
    printf 'edition=%s run_exit=0\n' "$edition"
    cat "$run_dir/logs/p31-tchk2-$edition.run.stdout"
    cat "$run_dir/logs/p31-tchk2-$edition.run.stderr" >&2
  else
    rc=$?
    printf 'edition=%s run_exit=%s\n' "$edition" "$rc"
    status=1
  fi
done
exit "$status"
