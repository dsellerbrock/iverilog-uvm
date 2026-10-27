#!/usr/bin/env bash
#SBATCH --job-name=a3-c07b-methodsr
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
EXPECTED="$RUN_DIR/input/expected.txt"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC"/*.sv "$EXPECTED" > "$OUT/SHA256SUMS"
printf 'edition\tcase\tcompile_rc\trun_rc\tstdout_match\n' > "$OUT/results.tsv"
for edition in 2017 2023; do
  image="$OUT/p07_12_methods_r-g$edition.vvp"
  if /usr/bin/time -f '%e %M' -o "$OUT/logs/methods-g$edition.compile.time" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s p07_12_methods -o "$image" "$SRC/p07_12_methods_r.sv" > "$OUT/logs/methods-g$edition.compile.log" 2>&1; then
    crc=0
    if /usr/bin/time -f '%e %M' -o "$OUT/logs/methods-g$edition.run.time" timeout --kill-after=2s 30s "$VVP" "$image" > "$OUT/logs/methods-g$edition.stdout.log" 2> "$OUT/logs/methods-g$edition.stderr.log"; then
      rrc=0
      if diff -u "$EXPECTED" "$OUT/logs/methods-g$edition.stdout.log" > "$OUT/logs/methods-g$edition.diff"; then match=YES; else match=NO; fi
    else rrc=$?; match=RUN_FAILED; fi
  else crc=$?; rrc=NA; match=COMPILE_FAILED; fi
  printf '%s\tmethods_r\t%s\t%s\t%s\n' "$edition" "$crc" "$rrc" "$match" >> "$OUT/results.tsv"
  neg="$OUT/n07_12_shuffle_with-g$edition.vvp"
  if /usr/bin/time -f '%e %M' -o "$OUT/logs/shuffle-with-g$edition.compile.time" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s n07_12_shuffle_with -o "$neg" "$SRC/n07_12_shuffle_with.sv" > "$OUT/logs/shuffle-with-g$edition.compile.log" 2>&1; then
    nrc=0 nresult=ACCEPTED
  else nrc=$?; if [ "$nrc" -ge 124 ]; then nresult=TIMEOUT; else nresult=REJECTED; fi; fi
  printf '%s\tshuffle_with_negative\t%s\tNA\t%s\n' "$edition" "$nrc" "$nresult" >> "$OUT/results.tsv"
done
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.stdout.log "$OUT"/logs/*.stderr.log; do [ -f "$f" ] && { echo "--- ${f##*/}"; cat "$f"; }; done
