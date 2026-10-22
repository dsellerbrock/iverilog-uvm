#!/usr/bin/env bash
#SBATCH --job-name=a3-c06-c1-corr
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c06-nets-followup-2-corrected-c1-20261021-01
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c06-nets-followup-2-corrected-c1-20261021-01/logs/slurm-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/A3/ieee1800-audit-c06-nets-followup-2-corrected-c1-20261021-01/logs/slurm-%j.err
set -u
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
mkdir -p results logs
date -Is > results/start-time.txt
scontrol show job "$SLURM_JOB_ID" > results/scontrol-at-start.txt 2>&1 || true
printf 'case\tedition\tcompile_rc\trun_rc\n' > results/status.tsv
{
  echo 'Host: DAN-DESKTOP'
  echo 'Icarus 13.0 devel (cc25756d1)'
  echo "Toolchain root: $IVL_ROOT"
  "$IVL_ROOT/bin/iverilog" -V 2>&1 | sed -n '1p'
  "$IVL_ROOT/bin/vvp" -V 2>&1 | sed -n '1p'
  sha256sum "$IVL_ROOT/bin/iverilog" "$IVL_ROOT/bin/vvp"
} > results/toolchain.txt
{
  echo 'ulimit -f 262144'
  ulimit -f 262144
  ulimit -f
  ulimit -a
} > results/resource-limits.txt 2>&1
src=input/C1_struct_variable_drives_net.sv
name=${src##*/}
name=${name%.sv}
for edition in 2017 2023; do
  compile_log="logs/$name-g$edition.compile.log"
  run_log="logs/$name-g$edition.run.log"
  out="results/$name-g$edition.vvp"
  (ulimit -f 262144; timeout --signal=TERM --kill-after=5s 30s "$IVL_ROOT/bin/iverilog" \
    -B "$IVL_ROOT/lib/ivl" -g"$edition" -gassertions -o "$out" "$src") >"$compile_log" 2>&1
  crc=$?
  rrc=NA
  if [ "$crc" -eq 0 ]; then
    (ulimit -f 262144; timeout --signal=TERM --kill-after=5s 30s "$IVL_ROOT/bin/vvp" "$out") >"$run_log" 2>&1
    rrc=$?
  fi
  printf '%s\t%s\t%s\t%s\n' "$name" "$edition" "$crc" "$rrc" | tee -a results/status.tsv
done
date -Is > results/end-time.txt
sha256sum "$IVL_ROOT/bin/iverilog" "$IVL_ROOT/bin/vvp" > results/toolchain-SHA256SUMS
sha256sum "$src" > results/source-SHA256SUMS
du -h results/*.vvp > results/vvp-sizes.txt 2>&1 || true
df -h /home/dsell/slurm-runs > results/df-before-cleanup.txt 2>&1 || true
exit 0
