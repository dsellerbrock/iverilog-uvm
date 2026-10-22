#!/usr/bin/env bash
#SBATCH --job-name=a3-c18-order-static-r2
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=logs/job-%j.out
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
printf 'edition\tprobe\texpected\tcompile_rc\trun_rc\tfirst_diagnostic\n' > "$OUT/negative.tsv"
for edition in 2017 2023; do
  for name in p18_05_order_dist p18_05_static_mode; do
    src="$RUN_DIR/input/$name.sv"
    image="$OUT/$name-g$edition.vvp"
    log="$OUT/logs/$name-g$edition.log"
    if python3 "$TIMEOUT" 30 -- "$IVL" -g"$edition" -o "$image" "$src" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
    run_rc=NA
    if [ "$compile_rc" -eq 0 ]; then
      if python3 "$TIMEOUT" 30 -- "$VVP" "$image" >> "$log" 2>&1; then run_rc=0; else run_rc=$?; fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" >> "$OUT/positive.tsv"
  done

  name=p18_05_solve_real
  src="$RUN_DIR/input/$name.sv"
  image="$OUT/$name-g$edition.vvp"
  log="$OUT/logs/$name-g$edition.log"
  if python3 "$TIMEOUT" 30 -- "$IVL" -g"$edition" -o "$image" "$src" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
  run_rc=NA
  if [ "$edition" = 2023 ] && [ "$compile_rc" -eq 0 ]; then
    if python3 "$TIMEOUT" 30 -- "$VVP" "$image" >> "$log" 2>&1; then run_rc=0; else run_rc=$?; fi
  fi
  expected=2017-rand-real-rejected
  if [ "$edition" = 2023 ]; then expected=2023-rand-real-run; fi
  printf '%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" >> "$OUT/positive.tsv"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$edition" "$name" "$expected" "$compile_rc" "$run_rc" "$(head -n 1 "$log" | tr '\t' ' ')" >> "$OUT/negative.tsv"

  for name in n18_05_solve_randc n18_05_solve_nonrand n18_05_solve_circular n18_05_static_mismatch; do
    src="$RUN_DIR/input/$name.sv"
    image="$OUT/$name-g$edition.vvp"
    log="$OUT/logs/$name-g$edition.log"
    if python3 "$TIMEOUT" 30 -- "$IVL" -g"$edition" -o "$image" "$src" > "$log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
    run_rc=NA
    if [ "$compile_rc" -eq 0 ]; then
      if python3 "$TIMEOUT" 30 -- "$VVP" "$image" >> "$log" 2>&1; then run_rc=0; else run_rc=$?; fi
    fi
    printf '%s\t%s\tcompile-error\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" "$(head -n 1 "$log" | tr '\t' ' ')" >> "$OUT/negative.tsv"
  done
done
cat "$OUT/positive.tsv"
cat "$OUT/negative.tsv"
