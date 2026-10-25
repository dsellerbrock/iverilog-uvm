#!/usr/bin/env bash
#SBATCH --job-name=a3-c15-lead
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
set -euo pipefail
RUN_DIR="$(pwd)"
IVL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/vvp
INPUT="$RUN_DIR/input"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$INPUT"/*.sv "$INPUT/run_with_timeout.py" > "$OUT/SHA256SUMS"
printf 'edition\tprobe\tcompile_rc\trun_rc\n' > "$OUT/results.tsv"
for edition in 2017 2023; do
  for name in p15_03a_semaphore p15_05a_events r15_wait_order_fail; do
    image="$OUT/$name-g$edition.vvp"
    log="$OUT/logs/$name-g$edition.log"
    if python3 "$INPUT/run_with_timeout.py" 20 -- "$IVL" -g"$edition" -o "$image" "$INPUT/$name.sv" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
    run_rc=NA
    if [ "$compile_rc" -eq 0 ]; then
      if python3 "$INPUT/run_with_timeout.py" 20 -- "$VVP" "$image" >> "$log" 2>&1; then run_rc=0; else run_rc=$?; fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" >> "$OUT/results.tsv"
  done
done
cat "$OUT/results.tsv"
