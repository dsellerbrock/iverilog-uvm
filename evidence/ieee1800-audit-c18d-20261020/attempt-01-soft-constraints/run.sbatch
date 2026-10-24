#!/usr/bin/env bash
#SBATCH --job-name=a3-c15-c18-lead
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
TIMEOUT="$RUN_DIR/input/c18/run_with_timeout.py"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$RUN_DIR/input"/c15/*.sv "$RUN_DIR/input"/c18/*.sv "$RUN_DIR/input"/c15/run_with_timeout.py "$RUN_DIR/input"/c18/run_with_timeout.py > "$OUT/SHA256SUMS"
printf 'edition\tprobe\tcompile_rc\tfirst_diagnostic\n' > "$OUT/c15-reducers.tsv"
printf 'edition\tprobe\tcompile_rc\trun_rc\n' > "$OUT/c18-soft.tsv"
for edition in 2017 2023; do
  for name in ev_formal_only ev_call_fork_only; do
    src="$RUN_DIR/input/c15/$name.sv"
    image="$OUT/$name-g$edition.vvp"
    log="$OUT/logs/$name-g$edition.log"
    if python3 "$TIMEOUT" 20 -- "$IVL" -g"$edition" -o "$image" "$src" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
    diagnostic="$(head -n 1 "$log" | tr '\t' ' ')"
    printf '%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$diagnostic" >> "$OUT/c15-reducers.tsv"
  done
  for name in p18_05_soft neg_n18_soft_randc; do
    src="$RUN_DIR/input/c18/$name.sv"
    image="$OUT/$name-g$edition.vvp"
    log="$OUT/logs/$name-g$edition.log"
    if python3 "$TIMEOUT" 20 -- "$IVL" -g"$edition" -o "$image" "$src" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
    run_rc=NA
    if [ "$compile_rc" -eq 0 ]; then
      if python3 "$TIMEOUT" 20 -- "$VVP" "$image" >> "$log" 2>&1; then run_rc=0; else run_rc=$?; fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" >> "$OUT/c18-soft.tsv"
  done
done
cat "$OUT/c15-reducers.tsv"
cat "$OUT/c18-soft.tsv"
