#!/usr/bin/env bash
#SBATCH --job-name=a3-c14-k3-direct
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=logs/slurm-%j.out
#SBATCH --error=logs/slurm-%j.err
set -u
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
mkdir -p results logs
printf 'edition\tcompile_rc\trun_rc\n' > results/k3-direct-status.tsv
for edition in 2017 2023; do
  timeout --signal=TERM --kill-after=5s 30s "$IVL_ROOT/bin/iverilog" \
    -B "$IVL_ROOT/lib/ivl" -g"$edition" -o "results/k3-direct-g$edition.vvp" \
    input/k3_direct_hier_cycle_delayed_drive.sv >"logs/k3-direct-g$edition.compile.log" 2>&1
  crc=$?
  rrc=NA
  if [ "$crc" -eq 0 ]; then
    timeout --signal=TERM --kill-after=5s 30s "$IVL_ROOT/bin/vvp" \
      "results/k3-direct-g$edition.vvp" >"logs/k3-direct-g$edition.run.log" 2>&1
    rrc=$?
  fi
  cat "logs/k3-direct-g$edition.compile.log"
  if [ -f "logs/k3-direct-g$edition.run.log" ]; then cat "logs/k3-direct-g$edition.run.log"; fi
  printf '%s\t%s\t%s\n' "$edition" "$crc" "$rrc" | tee -a results/k3-direct-status.tsv
done
sha256sum "$IVL_ROOT/bin/iverilog" "$IVL_ROOT/bin/vvp" input/k3_direct_hier_cycle_delayed_drive.sv > results/k3-direct-SHA256SUMS
