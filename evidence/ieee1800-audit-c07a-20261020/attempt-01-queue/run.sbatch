#!/usr/bin/env bash
#SBATCH --job-name=a3-c07a-queue
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
SRC="$RUN_DIR/input/tests/1800_audit/c07/p07_10_queue.sv"
EXPECTED="$RUN_DIR/input/expected.txt"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC" "$EXPECTED" > "$OUT/SHA256SUMS"
printf 'edition\tcompile_rc\trun_rc\tstdout_match\n' > "$OUT/results.tsv"
for edition in 2017 2023; do
  image="$OUT/p07_10_queue-g$edition.vvp"
  if /usr/bin/time -f '%e %M' -o "$OUT/logs/compile-g$edition.time" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s p07_10_queue -o "$image" "$SRC" > "$OUT/logs/compile-g$edition.log" 2>&1; then
    crc=0
    if /usr/bin/time -f '%e %M' -o "$OUT/logs/run-g$edition.time" timeout --kill-after=2s 30s "$VVP" "$image" > "$OUT/logs/run-g$edition.stdout.log" 2> "$OUT/logs/run-g$edition.stderr.log"; then
      rrc=0
      if diff -u "$EXPECTED" "$OUT/logs/run-g$edition.stdout.log" > "$OUT/logs/diff-g$edition.log"; then match=YES; else match=NO; fi
    else rrc=$?; match=RUN_FAILED; fi
  else crc=$?; rrc=NA; match=COMPILE_FAILED; fi
  printf '%s\t%s\t%s\t%s\n' "$edition" "$crc" "$rrc" "$match" >> "$OUT/results.tsv"
done
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.stdout.log "$OUT"/logs/*.stderr.log; do [ -f "$f" ] && { echo "--- ${f##*/}"; cat "$f"; }; done
