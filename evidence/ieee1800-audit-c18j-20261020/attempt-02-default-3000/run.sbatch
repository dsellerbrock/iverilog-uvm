#!/usr/bin/env bash
#SBATCH --job-name=a3-c18j-e4
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
sha256sum "$IVL" "$VVP" "$RUN_DIR/input/p18_05_3_default.sv" "$TIMEOUT" > "$OUT/SHA256SUMS"

name=p18_05_3_default
src="$RUN_DIR/input/$name.sv"
image="$OUT/$name-g2023.vvp"
compile_log="$OUT/logs/$name-g2023.compile.log"
if python3 "$TIMEOUT" 30 -- "$IVL" -g2023 -s "$name" -o "$image" "$src" > "$compile_log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
run_rc=NA
if [ "$compile_rc" -eq 0 ]; then
  if python3 "$TIMEOUT" 30 -- /usr/bin/time -p "$VVP" "$image" > "$OUT/logs/$name-g2023.run.log" 2>&1; then run_rc=0; else run_rc=$?; fi
fi
date -u +%FT%TZ > "$OUT/end.utc"
printf 'edition\tprobe\tcompile_rc\trun_rc\n2023\t%s\t%s\t%s\n' "$name" "$compile_rc" "$run_rc" > "$OUT/results.tsv"
cat "$OUT/results.tsv"
