#!/usr/bin/env bash
#SBATCH --job-name=a3-664-red
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/issue664-noarg-concat-red-20261018-01
#SBATCH --output=logs/%x-%j.out

set -u
source_file=source/sv_class_method_noarg_string_concat.v
run_case() {
  tag=$1
  edition=$2
  compiler=$3
  out="results/${tag}-${edition}.stdout"
  err="results/${tag}-${edition}.stderr"
  image="results/${tag}-${edition}.vvp"
  timeout --signal=TERM --kill-after=5s 120s "$compiler" "-g${edition}" -s test -o "$image" "$source_file" >"$out" 2>"$err"
  compile_status=$?
  printf 'toolchain=%s edition=%s compile_exit=%s\n' "$tag" "$edition" "$compile_status" >>results/result.txt
  if [ "$compile_status" -eq 0 ]; then
    timeout --signal=TERM --kill-after=5s 120s "${compiler%/iverilog}/vvp" -n "$image" >>"$out" 2>>"$err"
    run_status=$?
    printf 'toolchain=%s edition=%s run_exit=%s\n' "$tag" "$edition" "$run_status" >>results/result.txt
  fi
}
: >results/result.txt
old_compiler=/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/bin/iverilog
branch_compiler=/home/dsell/toolchains/iverilog-a3-m7-457-guard-c344-d884d145/bin/iverilog
sha256sum "$old_compiler" "$branch_compiler" >results/toolchains.sha256
"$old_compiler" -V >results/old-version.txt 2>&1
"$branch_compiler" -V >results/branch-version.txt 2>&1
sha256sum "$source_file" >results/source.sha256
run_case a2-pinned 2017 "$old_compiler"
run_case a2-pinned 2023 "$old_compiler"
run_case c344-branch 2017 "$branch_compiler"
run_case c344-branch 2023 "$branch_compiler"
cat results/result.txt
