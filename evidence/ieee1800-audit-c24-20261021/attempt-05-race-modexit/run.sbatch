#!/usr/bin/env bash
#SBATCH --job-name=a3-c24-race
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-3657
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
run_case() {
  name="$1"
  source="$2"
  edition="$3"
  output="$run_dir/build/$name-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -o "$output" "$source" >"$run_dir/logs/$name-$edition.compile.stdout" 2>"$run_dir/logs/$name-$edition.compile.stderr"; then
    compile_rc=0
  else
    compile_rc=$?
    status=1
  fi
  printf '%s edition=%s compile_exit=%s\n' "$name" "$edition" "$compile_rc"
  cat "$run_dir/logs/$name-$edition.compile.stderr"
  if [ "$compile_rc" -eq 0 ]; then
    if timeout --signal=TERM --kill-after=2s 30s "$vvp" "$output" >"$run_dir/logs/$name-$edition.run.stdout" 2>"$run_dir/logs/$name-$edition.run.stderr"; then
      run_rc=0
    else
      run_rc=$?
      status=1
    fi
    printf '%s edition=%s run_exit=%s\n' "$name" "$edition" "$run_rc"
    cat "$run_dir/logs/$name-$edition.run.stdout"
    cat "$run_dir/logs/$name-$edition.run.stderr"
  fi
}

for edition in 2017 2023; do
  run_case race_program p24_04_race.sv "$edition"
  run_case race_module p24_04_race_mod.sv "$edition"
  run_case module_exit p24_07_mod_exit.sv "$edition"
done
exit "$status"
