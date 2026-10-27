#!/usr/bin/env bash
#SBATCH --job-name=a3-c39-assert
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c39-20261021-01/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c39-20261021-01
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
iverilog_vpi="$toolchain/bin/iverilog-vpi"
base="$toolchain/lib/ivl"
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/build"

printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum "$run_dir/input/p39.sv" "$run_dir/input/p39_dis.sv" "$run_dir/input/vpi_assert.c" "$iverilog" "$vvp" "$iverilog_vpi" "$toolchain/include/iverilog/vpi_user.h" "$toolchain/include/iverilog/sv_vpi_user.h" "$toolchain/lib/libvpi.a" "$base/ivl" "$base/ivlpp"

if timeout --signal=TERM --kill-after=2s 60s "$iverilog_vpi" "$run_dir/input/vpi_assert.c" "-I$toolchain/include/iverilog" "-L$toolchain/lib" >"$run_dir/logs/vpi-build.stdout" 2>"$run_dir/logs/vpi-build.stderr"; then
  printf 'vpi_build_exit=0\n'
else
  rc=$?
  printf 'vpi_build_exit=%s\n' "$rc"
fi

for edition in 2017 2023; do
  for mode in main disable; do
    if test "$mode" = main; then
      source="$run_dir/input/p39.sv"
    else
      source="$run_dir/input/p39_dis.sv"
    fi
    output="$run_dir/build/p39-$mode-$edition.vvp"
    if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -s p39 -o "$output" "$source" >"$run_dir/logs/p39-$mode-$edition.compile.stdout" 2>"$run_dir/logs/p39-$mode-$edition.compile.stderr"; then
      printf 'edition=%s mode=%s compile_exit=0\n' "$edition" "$mode"
      if test -f "$run_dir/build/vpi_assert.vpi"; then
        if timeout --signal=TERM --kill-after=2s 30s "$vvp" -M. -mvpi_assert "$output" >"$run_dir/logs/p39-$mode-$edition.run.stdout" 2>"$run_dir/logs/p39-$mode-$edition.run.stderr"; then
          printf 'edition=%s mode=%s run_exit=0\n' "$edition" "$mode"
          cat "$run_dir/logs/p39-$mode-$edition.run.stdout"
        else
          rc=$?
          printf 'edition=%s mode=%s run_exit=%s\n' "$edition" "$mode" "$rc"
        fi
      else
        printf 'edition=%s mode=%s run_skipped=no_vpi_module\n' "$edition" "$mode"
      fi
    else
      rc=$?
      printf 'edition=%s mode=%s compile_exit=%s\n' "$edition" "$mode" "$rc"
    fi
  done
done
exit 0
