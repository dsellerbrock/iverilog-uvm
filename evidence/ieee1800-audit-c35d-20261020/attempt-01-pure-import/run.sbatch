#!/usr/bin/env bash
#SBATCH --job-name=a3-c35-pure-import
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=logs/job-%j.out
set -uo pipefail
RUN_DIR="$(pwd)"
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
IVL="$IVL_ROOT/bin/iverilog"
VVP="$IVL_ROOT/bin/vvp"
CC=/usr/bin/gcc
SRC="$RUN_DIR/input/dpi_basic_test.sv"
C_SRC="$RUN_DIR/input/dpi_basic_test.c"
EXP="$RUN_DIR/input/expected.txt"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs" "$RUN_DIR/scratch/2017" "$RUN_DIR/scratch/2023"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
"$VVP" -V > "$OUT/vvp-version.txt" 2>&1
"$CC" --version | head -n 1 > "$OUT/gcc-version.txt"
sha256sum "$IVL" "$VVP" "$CC" "$SRC" "$C_SRC" "$EXP" > "$OUT/SHA256SUMS"
printf 'edition\tcompile_rc\tlink_rc\trun_rc\tstdout_match\n' > "$OUT/results.tsv"
failed=0
for edition in 2017 2023; do
  work="$RUN_DIR/scratch/$edition"
  if (cd "$work" && /usr/bin/time -f '%e %M' -o "$OUT/logs/g$edition.compile.time" timeout --kill-after=2s 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$edition" -s top -o test.vvp "$SRC") > "$OUT/logs/g$edition.compile.log" 2>&1; then
    crc=0
  else
    crc=$?
    failed=1
  fi
  if [ "$crc" -eq 0 ]; then
    if (cd "$work" && /usr/bin/time -f '%e %M' -o "$OUT/logs/g$edition.link.time" timeout --kill-after=2s 30s "$CC" -shared -fPIC -o libdpi.so "$C_SRC") > "$OUT/logs/g$edition.link.log" 2>&1; then
      lrc=0
    else
      lrc=$?
      failed=1
    fi
  else
    lrc=NA
  fi
  if [ "$crc" -eq 0 ] && [ "$lrc" -eq 0 ]; then
    if (cd "$work" && /usr/bin/time -f '%e %M' -o "$OUT/logs/g$edition.run.time" timeout --kill-after=2s 30s "$VVP" -d ./libdpi.so ./test.vvp) > "$OUT/logs/g$edition.stdout.log" 2> "$OUT/logs/g$edition.stderr.log"; then
      rrc=0
    else
      rrc=$?
      failed=1
    fi
  else
    rrc=NA
  fi
  if [ "$rrc" = 0 ] && diff -u "$EXP" "$OUT/logs/g$edition.stdout.log" > "$OUT/logs/g$edition.diff"; then
    match=YES
  else
    match=NO
    failed=1
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$edition" "$crc" "$lrc" "$rrc" "$match" >> "$OUT/results.tsv"
done
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.link.log "$OUT"/logs/*.stdout.log "$OUT"/logs/*.stderr.log; do
  [ -f "$f" ] || continue
  echo "--- ${f##*/}"
  cat "$f"
done
exit "$failed"
