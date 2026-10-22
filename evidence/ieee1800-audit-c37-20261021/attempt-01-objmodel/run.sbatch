#!/usr/bin/env bash
#SBATCH --job-name=a3-c37-vpi
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c37-obj-20261021-a1/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/A3/c37-obj-20261021-a1
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
iverilog_vpi="$toolchain/bin/iverilog-vpi"
base="$toolchain/lib/ivl"

mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/build"
printf 'host=%s\n' "$(hostname)"
printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
printf 'toolchain=%s\n' "$toolchain"
sha256sum "$run_dir/input/p37.sv" "$run_dir/input/vpi_obj.c" \
  "$iverilog" "$vvp" "$iverilog_vpi" \
  "$toolchain/include/iverilog/vpi_user.h" "$toolchain/lib/libvpi.a" \
  "$base/ivl" "$base/ivlpp"

if timeout --signal=TERM --kill-after=2s 60s "$iverilog_vpi" \
  "$run_dir/input/vpi_obj.c" "-I$toolchain/include/iverilog" "-L$toolchain/lib" \
  >"$run_dir/logs/vpi-build.stdout" 2>"$run_dir/logs/vpi-build.stderr"; then
  printf 'vpi_build_exit=0\n'
else
  rc=$?
  printf 'vpi_build_exit=%s\n' "$rc"
fi

for edition in 2017 2023; do
  output="$run_dir/build/p37-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" \
    "-g$edition" -s p37 -o "$output" "$run_dir/input/p37.sv" \
    >"$run_dir/logs/p37-$edition.compile.stdout" \
    2>"$run_dir/logs/p37-$edition.compile.stderr"; then
    printf 'edition=%s compile_exit=0\n' "$edition"
    if test -f "$run_dir/build/vpi_obj.vpi"; then
      if timeout --signal=TERM --kill-after=2s 30s "$vvp" -M. -mvpi_obj "$output" \
        >"$run_dir/logs/p37-$edition.run.stdout" \
        2>"$run_dir/logs/p37-$edition.run.stderr"; then
        printf 'edition=%s run_exit=0\n' "$edition"
        cat "$run_dir/logs/p37-$edition.run.stdout"
        cat "$run_dir/logs/p37-$edition.run.stderr" >&2
      else
        rc=$?
        printf 'edition=%s run_exit=%s\n' "$edition" "$rc"
      fi
    else
      printf 'edition=%s run_skipped=no_vpi_module\n' "$edition"
    fi
  else
    rc=$?
    printf 'edition=%s compile_exit=%s\n' "$edition" "$rc"
  fi
done
