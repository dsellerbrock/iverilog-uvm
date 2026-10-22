#!/usr/bin/env bash
#SBATCH --job-name=a3-c34-protect
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c34-20261021-01/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c34-20261021-01
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"

printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum ./*.sv "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"
for edition in 2017 2023; do
  for test in plain cipher; do
    output="$run_dir/build/p34-$test-$edition.vvp"
    source="p34_${test}.sv"
    if [[ "$test" == cipher ]]; then source=n34_cipher.sv; fi
    if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -s top -o "$output" "$source" >"$run_dir/logs/p34-$test-$edition.compile.stdout" 2>"$run_dir/logs/p34-$test-$edition.compile.stderr"; then
      if timeout --signal=TERM --kill-after=2s 10s "$vvp" "$output" >"$run_dir/logs/p34-$test-$edition.run.stdout" 2>"$run_dir/logs/p34-$test-$edition.run.stderr"; then
        printf 'test=%s edition=%s compile_exit=0 run_exit=0 output=%s\n' "$test" "$edition" "$(tr '\n' ' ' <"$run_dir/logs/p34-$test-$edition.run.stdout")"
      else
        rc=$?
        printf 'test=%s edition=%s compile_exit=0 run_exit=%s\n' "$test" "$edition" "$rc"
      fi
    else
      rc=$?
      printf 'test=%s edition=%s compile_exit=%s\n' "$test" "$edition" "$rc"
    fi
  done
done
exit 0
