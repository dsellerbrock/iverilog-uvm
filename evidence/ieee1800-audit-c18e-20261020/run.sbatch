#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-foreach
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
TIMEOUT="$RUN_DIR/input/run_with_timeout.py"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$RUN_DIR/input"/*.sv "$TIMEOUT" > "$OUT/SHA256SUMS"
printf 'edition\tprobe\tcompile_rc\trun_rc\n' > "$OUT/positive.tsv"
printf 'edition\tprobe\tcompile_rc\tfirst_diagnostic\n' > "$OUT/negative.tsv"
for edition in 2017 2023; do
  name=p18_05_foreach
  src="$RUN_DIR/input/$name.sv"
  image="$OUT/$name-g$edition.vvp"
  log="$OUT/logs/$name-g$edition.log"
  if python3 "$TIMEOUT" 20 -- "$IVL" -g"$edition" -o "$image" "$src" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
  run_rc=NA
  if [ "$compile_rc" -eq 0 ]; then
    if python3 "$TIMEOUT" 20 -- "$VVP" "$image" >> "$log" 2>&1; then run_rc=0; else run_rc=$?; fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" >> "$OUT/positive.tsv"
  for name in neg_n18_foreach_samename neg_n18_foreach_toomany; do
    src="$RUN_DIR/input/$name.sv"
    log="$OUT/logs/$name-g$edition.log"
    if python3 "$TIMEOUT" 20 -- "$IVL" -g"$edition" -o /dev/null "$src" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
    diagnostic="$(head -n 1 "$log" | tr '\t' ' ')"
    printf '%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$diagnostic" >> "$OUT/negative.tsv"
  done
done
cat "$OUT/positive.tsv"
cat "$OUT/negative.tsv"
