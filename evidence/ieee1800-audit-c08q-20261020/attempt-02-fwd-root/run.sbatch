#!/usr/bin/env bash
#SBATCH --job-name=a3-c08q-fwdroot
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
SRC="$RUN_DIR/input/tests/1800_audit/c08/p08_27_fwd_param.sv"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC" > "$OUT/SHA256SUMS"
printf 'edition\tcompile_rc\trun_rc\tresult\n' > "$OUT/results.tsv"
printf 'FP 1 2 64\n' > "$OUT/expected.txt"
failures=0
for edition in 2017 2023; do
  image="$OUT/p08_27_fwd_param-g$edition.vvp"
  if /usr/bin/time -f '%e %M' -o "$OUT/logs/compile-g$edition.time" timeout --kill-after=2s 30s "$IVL" -g"$edition" -s top -o "$image" "$SRC" > "$OUT/logs/compile-g$edition.log" 2>&1; then
    crc=0
    if /usr/bin/time -f '%e %M' -o "$OUT/logs/run-g$edition.time" timeout --kill-after=2s 30s "$VVP" "$image" > "$OUT/logs/run-g$edition.log" 2>&1; then
      rrc=0
      if diff -u "$OUT/expected.txt" "$OUT/logs/run-g$edition.log" > "$OUT/logs/diff-g$edition.log"; then result=PASS; else result=OUTPUT_MISMATCH; failures=1; fi
    else rrc=$?; result=RUN_FAILED; failures=1; fi
  else crc=$?; rrc=NA; result=COMPILE_FAILED; failures=1; fi
  printf '%s\t%s\t%s\t%s\n' "$edition" "$crc" "$rrc" "$result" >> "$OUT/results.tsv"
done
date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
for f in "$OUT"/logs/*.compile.log "$OUT"/logs/*.run.log; do [ -f "$f" ] && { echo "--- ${f##*/}"; cat "$f"; }; done
exit "$failures"
