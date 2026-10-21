#!/usr/bin/env bash
#SBATCH --job-name=a3-c32-sdf-fix
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c32-20261021-02/logs/%x-%j.out
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c32-20261021-02
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
base="$toolchain/lib/ivl"
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"

printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum ./*.sv ./*.sdf
sha256sum "$iverilog" "$vvp" "$base/ivl" "$base/ivlpp"

status=0
for edition in 2017 2023; do
  for test in p32_sdf p32_pp; do
    output="$run_dir/build/$test-$edition-specify.vvp"
    if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -gspecify -o "$output" "$test.sv" >"$run_dir/logs/$test-$edition-specify.compile.stdout" 2>"$run_dir/logs/$test-$edition-specify.compile.stderr"; then
      printf 'test=%s edition=%s mode=specify compile_exit=0\n' "$test" "$edition"
    else
      rc=$?
      printf 'test=%s edition=%s mode=specify compile_exit=%s\n' "$test" "$edition" "$rc"
      status=1
      continue
    fi
    if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" >"$run_dir/logs/$test-$edition-specify.run.stdout" 2>"$run_dir/logs/$test-$edition-specify.run.stderr"; then
      printf 'test=%s edition=%s mode=specify run_exit=0\n' "$test" "$edition"
    else
      rc=$?
      printf 'test=%s edition=%s mode=specify run_exit=%s\n' "$test" "$edition" "$rc"
      status=1
    fi
  done
done

output="$run_dir/build/p32_sdf-2023-default.vvp"
if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" -g2023 -o "$output" p32_sdf.sv >"$run_dir/logs/p32_sdf-2023-default.compile.stdout" 2>"$run_dir/logs/p32_sdf-2023-default.compile.stderr"; then
  printf 'test=p32_sdf edition=2023 mode=default compile_exit=0\n'
  if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" >"$run_dir/logs/p32_sdf-2023-default.run.stdout" 2>"$run_dir/logs/p32_sdf-2023-default.run.stderr"; then
    printf 'test=p32_sdf edition=2023 mode=default run_exit=0\n'
  else
    rc=$?
    printf 'test=p32_sdf edition=2023 mode=default run_exit=%s\n' "$rc"
    status=1
  fi
else
  rc=$?
  printf 'test=p32_sdf edition=2023 mode=default compile_exit=%s\n' "$rc"
  status=1
fi
exit "$status"
