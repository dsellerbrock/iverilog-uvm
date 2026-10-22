#!/usr/bin/env bash
#SBATCH --job-name=a3-c22-fileline
#SBATCH --partition=verilog
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00

set -euo pipefail
run_dir=/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c22-20261020-001
toolchain=/home/dsell/toolchains/iverilog-fb584a25-20261020
mkdir -p "$run_dir/build" "$run_dir/logs"
cd "$run_dir/input"

printf 'source_head=%s\n' "$(sed -n 's/^source_head=//p' "$toolchain/BUILD-INFO")"
printf 'edition_flag=-g2012 (no edition-specific difference in §22.13)\n'
sha256sum ivltests/br_gh782a.v ivltests/br_gh782a.vi expected.gold
timeout --signal=TERM --kill-after=2s 30s \
  "$toolchain/bin/iverilog" -g2012 -I . -s test \
  -o "$run_dir/build/br_gh782a.vvp" ./ivltests/br_gh782a.v \
  >"$run_dir/logs/compile.stdout" 2>"$run_dir/logs/compile.stderr"
timeout --signal=TERM --kill-after=2s 30s \
  "$toolchain/bin/vvp" "$run_dir/build/br_gh782a.vvp" \
  >"$run_dir/logs/run.stdout" 2>"$run_dir/logs/run.stderr"
diff -u expected.gold "$run_dir/logs/run.stdout"
cat "$run_dir/logs/run.stdout"
echo 'PROBE_RESULT=PASS'
