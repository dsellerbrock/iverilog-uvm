#!/usr/bin/env bash
#SBATCH --job-name=a3-c07a-lviso
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00
#SBATCH --output=logs/job-%j.out
set -euo pipefail
RUN_DIR="$(pwd)"
IVL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/vvp
SRC="$RUN_DIR/input/tests/1800_audit/c07"
EXP="$RUN_DIR/input/expected"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC"/*.sv "$EXP"/*.txt > "$OUT/SHA256SUMS"
printf 'edition\tcase\tcompile_rc\trun_rc\tstdout_match\n' > "$OUT/results.tsv"
run_case() {
  local edition="$1" label="$2" source="$3" root="$4" expected="$5"
  local image="$OUT/$label-g$edition.vvp" compile_log="$OUT/logs/$label-g$edition.compile.log"
  local stdout="$OUT/logs/$label-g$edition.stdout.log" stderr="$OUT/logs/$label-g$edition.stderr.log"
  if /usr/bin/time -f '%e %M' -o "$OUT/logs/$label-g$edition.compile.time" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s "$root" -o "$image" "$source" > "$compile_log" 2>&1; then
    local crc=0
    if /usr/bin/time -f '%e %M' -o "$OUT/logs/$label-g$edition.run.time" timeout --kill-after=2s 30s "$VVP" "$image" > "$stdout" 2> "$stderr"; then
      local rrc=0 match=YES
      if ! diff -u "$expected" "$stdout" > "$OUT/logs/$label-g$edition.diff"; then match=NO; fi
    else local rrc=$? match=RUN_FAILED; fi
  else local crc=$? rrc=NA match=COMPILE_FAILED; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$edition" "$label" "$crc" "$rrc" "$match" >> "$OUT/results.tsv"
}
for edition in 2017 2023; do
  for n in 1 2 3 4 5; do run_case "$edition" "lv$n" "$SRC/p07_10_lv$n.sv" "p07_10_lv$n" "$EXP/lv$n.txt"; done
  run_case "$edition" queue_size "$SRC/p07_10_queue_size.sv" p07_10_queue "$EXP/full.txt"
done
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
: > "$OUT/warnings.txt"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.stdout.log "$OUT"/logs/*.stderr.log; do
  [ -f "$f" ] || continue
  grep -in 'warning' "$f" >> "$OUT/warnings.txt" || true
done
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.stdout.log "$OUT"/logs/*.stderr.log; do [ -f "$f" ] && { echo "--- ${f##*/}"; cat "$f"; }; done
printf '%s\n' '--- warning lines (verbatim with source filenames/line numbers)'; cat "$OUT/warnings.txt"
