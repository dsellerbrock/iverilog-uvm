#!/usr/bin/env bash
#SBATCH --job-name=a3-c35-string-array
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=logs/job-%j.out
set -uo pipefail
RUN_DIR="$(pwd)"
IVL_ROOT=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb
IVL="$IVL_ROOT/bin/iverilog"
VVP="$IVL_ROOT/bin/vvp"
CC=/usr/bin/gcc
mkdir -p "$RUN_DIR/results/logs"
date -u +%FT%TZ > "$RUN_DIR/results/start.utc"
hostname > "$RUN_DIR/results/host.txt"
uptime >> "$RUN_DIR/results/host.txt"
"$IVL" -V > "$RUN_DIR/results/iverilog-version.txt" 2>&1
"$VVP" -V > "$RUN_DIR/results/vvp-version.txt" 2>&1
"$CC" --version | head -n 1 > "$RUN_DIR/results/gcc-version.txt"
sha256sum "$IVL" "$VVP" "$CC" "$RUN_DIR/input"/* > "$RUN_DIR/results/SHA256SUMS"
printf 'edition\tcompile_rc\tlink_rc\trun_rc\toutcome\n' > "$RUN_DIR/results/results.tsv"
for edition in 2017 2023; do
  work="$RUN_DIR/scratch/$edition"
  mkdir -p "$work"
  if (cd "$work" && /usr/bin/time -f '%e %M' -o "$RUN_DIR/results/logs/$edition.compile.time" timeout --kill-after=2s 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$edition" -s p35_string_openarray -o test.vvp "$RUN_DIR/input/p35_string_openarray.sv") > "$RUN_DIR/results/logs/$edition.compile.log" 2>&1; then crc=0; else crc=$?; fi
  lrc=NA
  rrc=NA
  outcome=COMPILE_REJECTED
  if [ "$crc" -eq 0 ]; then
    if (cd "$work" && /usr/bin/time -f '%e %M' -o "$RUN_DIR/results/logs/$edition.link.time" timeout --kill-after=2s 30s "$CC" -shared -fPIC -I "$IVL_ROOT/include/iverilog" -o libdpi.so "$RUN_DIR/input/p35_string_openarray.c") > "$RUN_DIR/results/logs/$edition.link.log" 2>&1; then lrc=0; else lrc=$?; fi
    if [ "$lrc" -eq 0 ]; then
      if (cd "$work" && /usr/bin/time -f '%e %M' -o "$RUN_DIR/results/logs/$edition.run.time" timeout --kill-after=2s 30s "$VVP" -d ./libdpi.so ./test.vvp) > "$RUN_DIR/results/logs/$edition.stdout.log" 2> "$RUN_DIR/results/logs/$edition.stderr.log"; then rrc=0; else rrc=$?; fi
      if [ "$rrc" = 0 ] && grep -Fxq 'PASS string open-array size=2' "$RUN_DIR/results/logs/$edition.stdout.log"; then outcome=ACCEPTED; else outcome=RUNTIME_FAIL; fi
    else
      outcome=LINK_FAIL
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$edition" "$crc" "$lrc" "$rrc" "$outcome" >> "$RUN_DIR/results/results.tsv"
done
date -u +%FT%TZ > "$RUN_DIR/results/end.utc"
cat "$RUN_DIR/results/results.tsv"
for f in "$RUN_DIR/results"/logs/*.compile.log "$RUN_DIR/results"/logs/*.link.log "$RUN_DIR/results"/logs/*.stdout.log "$RUN_DIR/results"/logs/*.stderr.log; do [ -f "$f" ] || continue; echo "--- ${f##*/}"; cat "$f"; done
