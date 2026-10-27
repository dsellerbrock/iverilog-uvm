#!/usr/bin/env bash
#SBATCH --job-name=a3-c18l-impl-ifelse
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
printf 'edition\tprobe\tcompile_rc\trun_rc\n' > "$OUT/results.tsv"
run_case() {
  local edition="$1" name="$2"
  local src="$RUN_DIR/input/$name.sv"
  local image="$OUT/$name-g$edition.vvp"
  local compile_log="$OUT/logs/$name-g$edition.compile.log"
  local run_log="$OUT/logs/$name-g$edition.run.log"
  if python3 "$TIMEOUT" 30 -- "$IVL" -g"$edition" -s "$name" -o "$image" "$src" > "$compile_log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
  run_rc=NA
  if [ "$compile_rc" -eq 0 ]; then
    if python3 "$TIMEOUT" 30 -- "$VVP" "$image" > "$run_log" 2>&1; then run_rc=0; else run_rc=$?; fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" >> "$OUT/results.tsv"
}
run_case 2017 p18_05_6_impl_ifelse
run_case 2023 p18_05_6_impl_ifelse
run_case 2023 p18_05_5_real_pred
run_case 2017 p18_05_6_n_real_pred_2017
run_case 2023 p18_05_6_n_real_pred_2017
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for edition in 2017 2023; do
  for name in p18_05_6_impl_ifelse p18_05_5_real_pred p18_05_6_n_real_pred_2017; do
    for kind in run compile; do
      log="$OUT/logs/$name-g$edition.$kind.log"
      if [ -f "$log" ]; then echo "=== $name -g$edition $kind"; cat "$log"; fi
    done
  done
done
