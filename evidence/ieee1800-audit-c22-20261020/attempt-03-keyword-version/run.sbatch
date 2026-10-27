#!/usr/bin/env bash
#SBATCH --job-name=a3-c22-keywords
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
set -u
run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c22-20261020-003
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"
printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
for case_name in p22_14_keywords_2017 p22_14_keywords_2023 n22_14_unknown_keywords_version; do
  top=${case_name#*_}; top=${top#*_}; top=${top#*_}
  case "$case_name" in
    p22_14_keywords_2017) top=keywords_2017 ;;
    p22_14_keywords_2023) top=keywords_2023 ;;
    n22_14_unknown_keywords_version) top=unknown_keywords_version ;;
  esac
  set +e
  timeout --signal=TERM --kill-after=2s 30s "$toolchain/bin/iverilog" -g2012 -s "$top" -o "$run_dir/build/$case_name.vvp" "$case_name.sv" >"$run_dir/logs/$case_name.stdout" 2>"$run_dir/logs/$case_name.stderr"
  rc=$?
  set -e
  printf '%s compile_exit=%s\n' "$case_name" "$rc"
  cat "$run_dir/logs/$case_name.stderr"
done
