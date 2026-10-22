#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c16-sampled
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
set -euo pipefail
run_dir=${SLURM_SUBMIT_DIR:?}
toolchain=/home/dsell/toolchains/iverilog-a3-batch-6604c23e-f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd-53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b
iverilog="$toolchain/bin/iverilog"
vvp="$toolchain/bin/vvp"
printf 'source_sha=6604c23e197980b69a5b6b69864ff8ef8d05eba3\n'
printf 'iverilog_sha256=f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd\n'
printf 'vvp_sha256=53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b\n'
sha256sum "$run_dir/input/p16_09_03_sampled_procedural.sv"
for edition in 2017 2023; do
  stem="$run_dir/results/p16_09_03_sampled_procedural-$edition"
  timeout --signal=TERM --kill-after=5s 120s "$iverilog" -B "$toolchain/lib/ivl" -g"$edition" -gassertions -s test -o "$stem.vvp" "$run_dir/input/p16_09_03_sampled_procedural.sv" > "$stem.compile.log" 2>&1
  timeout --signal=TERM --kill-after=5s 120s "$vvp" -n "$stem.vvp" > "$stem.run.log" 2>&1
  echo "=== -g$edition ==="
  cat "$stem.run.log"
done
