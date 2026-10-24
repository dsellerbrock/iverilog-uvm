#!/usr/bin/env bash
#SBATCH --job-name=a3-c18k-real
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:03:00
#SBATCH --output=logs/job-%j.out
set -euo pipefail

RUN_DIR="$(pwd)"
IVL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/vvp
TIMEOUT="$RUN_DIR/input/run_with_timeout.py"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$RUN_DIR/input"/*.sv "$TIMEOUT" > "$OUT/SHA256SUMS"
name=p18_05_4_unique_real_scalar
if python3 "$TIMEOUT" 30 -- "$IVL" -g2023 -s "$name" -o "$OUT/$name.vvp" "$RUN_DIR/input/$name.sv" > "$OUT/logs/$name.compile.log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
run_rc=NA
if [ "$compile_rc" -eq 0 ]; then
  if python3 "$TIMEOUT" 30 -- "$VVP" "$OUT/$name.vvp" > "$OUT/logs/$name.run.log" 2>&1; then run_rc=0; else run_rc=$?; fi
fi
date -u +%FT%TZ > "$OUT/end.utc"
printf 'edition\tprobe\tcompile_rc\trun_rc\n2023\t%s\t%s\t%s\n' "$name" "$compile_rc" "$run_rc" > "$OUT/results.tsv"
cat "$OUT/results.tsv"
