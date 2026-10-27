#!/usr/bin/env bash
#SBATCH --job-name=a3-c24-items
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
set -uo pipefail

run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-3660
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
run_positive() {
  name="$1"
  source="$2"
  edition="$3"
  output="$run_dir/build/$name-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -o "$output" "$source" >"$run_dir/logs/$name-$edition.compile.stdout" 2>"$run_dir/logs/$name-$edition.compile.stderr"; then
    printf '%s edition=%s compile_exit=0\n' "$name" "$edition"
  else
    rc=$?
    printf '%s edition=%s compile_exit=%s\n' "$name" "$edition" "$rc"
    cat "$run_dir/logs/$name-$edition.compile.stderr"
    status=1
    return
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
}

run_negative() {
  name="$1"
  source="$2"
  edition="$3"
  output="$run_dir/build/$name-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$iverilog" -B "$base" "-g$edition" -o "$output" "$source" >"$run_dir/logs/$name-$edition.compile.stdout" 2>"$run_dir/logs/$name-$edition.compile.stderr"; then
    printf '%s edition=%s compile_exit=0 UNEXPECTED_ACCEPT\n' "$name" "$edition"
    status=1
  else
    rc=$?
    printf '%s edition=%s compile_exit=%s\n' "$name" "$edition" "$rc"
    cat "$run_dir/logs/$name-$edition.compile.stderr"
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
      status=1
    fi
  fi
}

for edition in 2017 2023; do
  run_positive p24_03_ok p24_03_ok.sv "$edition"
  run_negative n24_03_always n24_03_always.sv "$edition"
  run_negative n24_03_modinst n24_03_modinst.sv "$edition"
  run_negative n24_03_nested n24_03_nested.sv "$edition"
  run_negative n24_03_ifinst n24_03_ifinst.sv "$edition"
done
exit "$status"
