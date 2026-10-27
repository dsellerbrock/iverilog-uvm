#!/usr/bin/env bash
#SBATCH --job-name=a3-c18m-extern-inherit
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:11:00
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
printf 'edition\tprobe\tcompile_rc\trun_rc\texpected\n' > "$OUT/results.tsv"
run_case() {
  local edition="$1" name="$2" expected="$3"
  local src="$RUN_DIR/input/$name.sv"
  local image="$OUT/$name-g$edition.vvp"
  local compile_log="$OUT/logs/$name-g$edition.compile.log"
  local run_log="$OUT/logs/$name-g$edition.run.log"
  local top="$name"
  if [ "$name" != p18_05_1_extern_inherit ]; then top=m; fi
  if python3 "$TIMEOUT" 30 -- "$IVL" -g"$edition" -s "$top" -o "$image" "$src" > "$compile_log" 2>&1; then compile_rc=0; else compile_rc=$?; fi
  run_rc=NA
  if [ "$expected" = run ] && [ "$compile_rc" -eq 0 ]; then
    if python3 "$TIMEOUT" 30 -- "$VVP" "$image" > "$run_log" 2>&1; then run_rc=0; else run_rc=$?; fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$edition" "$name" "$compile_rc" "$run_rc" "$expected" >> "$OUT/results.tsv"
}
for edition in 2017 2023; do
  run_case "$edition" p18_05_1_extern_inherit run
  for n in 1 2 3 4 5 6; do run_case "$edition" "p18_05_1_n$n" reject; done
done
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.run.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"
  cat "$f"
done
