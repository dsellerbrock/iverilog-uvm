#!/usr/bin/env bash
#SBATCH --job-name=a3-c18l-bidir-iso
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
SRC="$RUN_DIR/input/p18_05_5_real_bidir_iso.sv"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC" "$TIMEOUT" > "$OUT/SHA256SUMS"
image="$OUT/p18_05_5_real_bidir_iso.vvp"
if python3 "$TIMEOUT" 60 -- "$IVL" -g2023 -s p18_05_5_real_bidir_iso -o "$image" "$SRC" > "$OUT/logs/compile.log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
run_rc=NA
if [ "$compile_rc" -eq 0 ]; then
  if python3 "$TIMEOUT" 60 -- "$VVP" "$image" > "$OUT/logs/run.log" 2>&1; then run_rc=0; else run_rc=$?; fi
fi
printf 'edition\tcompile_rc\trun_rc\n2023\t%s\t%s\n' "$compile_rc" "$run_rc" > "$OUT/results.tsv"
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
cat "$OUT/logs/compile.log"
cat "$OUT/logs/run.log" 2>/dev/null || true
