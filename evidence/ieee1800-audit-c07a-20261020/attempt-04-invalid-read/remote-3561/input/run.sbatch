#!/usr/bin/env bash
#SBATCH --job-name=a3-c07-invalid-read
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=logs/job-%j.out
set -uo pipefail
RUN_DIR="$(pwd)"
IVL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/vvp
SRC="$RUN_DIR/input/p07_10_invalid_read.sv"
OUT="$RUN_DIR/results"
EXP="$RUN_DIR/input/expected.txt"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC" "$EXP" > "$OUT/SHA256SUMS"
printf 'edition\tcompile_rc\trun_rc\tstdout_match\n' > "$OUT/results.tsv"
failed=0
for edition in 2017 2023; do
  image="$OUT/p07_10_invalid_read-g$edition.vvp"
  if /usr/bin/time -f '%e %M' -o "$OUT/logs/g$edition.compile.time" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s p07_10_invalid_read -o "$image" "$SRC" > "$OUT/logs/g$edition.compile.log" 2>&1; then
    crc=0
  else
    crc=$?
    failed=1
  fi
  if [ "$crc" -eq 0 ]; then
    if /usr/bin/time -f '%e %M' -o "$OUT/logs/g$edition.run.time" timeout --kill-after=2s 30s "$VVP" "$image" > "$OUT/logs/g$edition.stdout.log" 2> "$OUT/logs/g$edition.stderr.log"; then
      rrc=0
    else
      rrc=$?
      failed=1
    fi
  else
    rrc=NA
  fi
  if [ "$crc" -eq 0 ] && [ "$rrc" = 0 ] && diff -u "$EXP" "$OUT/logs/g$edition.stdout.log" > "$OUT/logs/g$edition.diff"; then
    match=YES
  else
    match=NO
    failed=1
  fi
  printf '%s\t%s\t%s\t%s\n' "$edition" "$crc" "$rrc" "$match" >> "$OUT/results.tsv"
done
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.stdout.log "$OUT"/logs/*.stderr.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"
  cat "$f"
done
exit "$failed"
