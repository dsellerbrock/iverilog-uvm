#!/usr/bin/env bash
#SBATCH --job-name=a3-c18i-dist2
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:08:00
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
printf 'edition\tcase\tcompile_rc\trun_rc\n' > "$OUT/positive.tsv"
printf 'edition\tprobe\tcompile_rc\tfirst_diagnostic\n' > "$OUT/negative.tsv"

for edition in 2017 2023; do
  name=p18_05_4_dist
  src="$RUN_DIR/input/$name.sv"
  image="$OUT/$name-g$edition.vvp"
  compile_log="$OUT/logs/$name-g$edition.compile.log"
  if python3 "$TIMEOUT" 30 -- "$IVL" -g"$edition" -s "$name" -o "$image" "$src" > "$compile_log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
  for test_case in 1 2 3 4 5 6 7; do
    log="$OUT/logs/$name-g$edition-case$test_case.log"
    run_rc=NA
    if [ "$compile_rc" -eq 0 ]; then
      if python3 "$TIMEOUT" 30 -- "$VVP" "$image" "+CASE=$test_case" > "$log" 2>&1; then run_rc=0; else run_rc=$?; fi
    fi
    printf '%s\tCASE=%s\t%s\t%s\n' "$edition" "$test_case" "$compile_rc" "$run_rc" >> "$OUT/positive.tsv"
  done

  for spec in 'p18_05_4_n1_randc' 'p18_05_4_n2_norand'; do
    src="$RUN_DIR/input/$spec.sv"
    log="$OUT/logs/$spec-g$edition.log"
    if python3 "$TIMEOUT" 30 -- "$IVL" -g"$edition" -s "$spec" -o /dev/null "$src" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
    printf '%s\t%s\t%s\t%s\n' "$edition" "$spec" "$compile_rc" "$(head -n 1 "$log" | tr '\t' ' ')" >> "$OUT/negative.tsv"
  done
done

date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/positive.tsv" "$OUT/negative.tsv"
