#!/usr/bin/env bash
#SBATCH --job-name=a3-c24-reactive
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
set -u
run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-001
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"
printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
sha256sum m6_reactive_region_test.sv
for edition in 2017 2023; do
  set +e
  timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/iverilog" "-g$edition" -o "$run_dir/build/m6-reactive-$edition.vvp" m6_reactive_region_test.sv >"$run_dir/logs/compile-$edition.stdout" 2>"$run_dir/logs/compile-$edition.stderr"
  compile_rc=$?
  echo "edition=$edition compile_exit=$compile_rc"
  if [ "$compile_rc" -eq 0 ]; then
    timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/vvp" "$run_dir/build/m6-reactive-$edition.vvp" >"$run_dir/logs/run-$edition.stdout" 2>"$run_dir/logs/run-$edition.stderr"
    run_rc=$?
    echo "edition=$edition run_exit=$run_rc"
    cat "$run_dir/logs/run-$edition.stdout"
  fi
  set -e
done
