#!/usr/bin/env bash
#SBATCH --job-name=a3-c19-opt-depth
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=logs/slurm-%j.out
#SBATCH --error=logs/slurm-%j.err
set -u
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
mkdir -p results logs
printf 'case\tedition\tcompile_rc\trun_rc\n' > results/status.tsv
failed=0
for src in input/*.sv; do
  name=$(basename "$src" .sv)
  for edition in 2017 2023; do
    compile_log="logs/${name}-g${edition}.compile.log"
    run_log="logs/${name}-g${edition}.run.log"
    echo "=== ${name} -g${edition} ==="
    timeout --signal=TERM --kill-after=10s 60s "$IVL_ROOT/bin/iverilog" -B "$IVL_ROOT/lib/ivl" -g"$edition" -o "results/${name}-g${edition}.vvp" "$src" >"$compile_log" 2>&1
    crc=$?
    rrc=NA
    if [ "$crc" -eq 0 ]; then
      timeout --signal=TERM --kill-after=10s 60s "$IVL_ROOT/bin/vvp" "results/${name}-g${edition}.vvp" >"$run_log" 2>&1
      rrc=$?
    else
      cat "$compile_log"
      failed=1
    fi
    if [ "$rrc" != NA ] && [ "$rrc" -ne 0 ]; then failed=1; fi
    cat "$compile_log"
    if [ -f "$run_log" ]; then cat "$run_log"; fi
    printf '%s\t%s\t%s\t%s\n' "$name" "$edition" "$crc" "$rrc" | tee -a results/status.tsv
  done
done
sha256sum "$IVL_ROOT/bin/iverilog" "$IVL_ROOT/bin/vvp" input/*.sv > results/SHA256SUMS
exit "$failed"
