#!/usr/bin/env bash
#SBATCH --job-name=a3-c18k-shapes
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
printf 'edition\tprobe\tcompile_rc\trun_rc\texpected\tfirst_diagnostic\n' > "$OUT/results.tsv"

for edition in 2017 2023; do
  for name in p18_05_5_unique_shapes p18_05_4_unique_real_scalar; do
    src="$RUN_DIR/input/$name.sv"
    image="$OUT/$name-g$edition.vvp"
    compile_log="$OUT/logs/$name-g$edition.compile.log"
    run_log="$OUT/logs/$name-g$edition.run.log"
    if python3 "$TIMEOUT" 30 -- "$IVL" -g"$edition" -s "$name" -o "$image" "$src" > "$compile_log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
    run_rc=NA
    if [ "$compile_rc" -eq 0 ]; then
      if python3 "$TIMEOUT" 30 -- "$VVP" "$image" > "$run_log" 2>&1; then run_rc=0; else run_rc=$?; fi
    fi
    if [ "$name" = p18_05_5_unique_shapes ] || [ "$edition" = 2023 ]; then expected=run; else expected=reject; fi
    first_diagnostic="$(head -n 1 "$compile_log" | tr '\t' ' ')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" "$expected" "$first_diagnostic" >> "$OUT/results.tsv"
  done
done

date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
