#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-localinit
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
mkdir -p "$RUN_DIR/results/logs" "$RUN_DIR/scratch"
date -u +%FT%TZ > "$RUN_DIR/results/start.utc"
hostname > "$RUN_DIR/results/host.txt"
"$IVL" -V > "$RUN_DIR/results/iverilog-version.txt" 2>&1
"$VVP" -V > "$RUN_DIR/results/vvp-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$RUN_DIR/input/p16_13_7_local_init_multiclock.sv" > "$RUN_DIR/results/SHA256SUMS"
printf 'edition\tcompile_rc\trun_rc\tpass\n' > "$RUN_DIR/results/results.tsv"
failed=0
for edition in 2017 2023; do
  work="$RUN_DIR/scratch/$edition"
  mkdir -p "$work"
  if (cd "$work" && timeout --kill-after=2s 30s "$IVL" -B "$IVL_ROOT/lib/ivl" -g"$edition" -s p16_13_7_local_init_multiclock -o test.vvp "$RUN_DIR/input/p16_13_7_local_init_multiclock.sv") > "$RUN_DIR/results/logs/$edition.compile.log" 2>&1; then crc=0; else crc=$?; failed=1; fi
  if [ "$crc" -eq 0 ]; then
    if (cd "$work" && timeout --kill-after=2s 30s "$VVP" ./test.vvp) > "$RUN_DIR/results/logs/$edition.stdout.log" 2> "$RUN_DIR/results/logs/$edition.stderr.log"; then rrc=0; else rrc=$?; failed=1; fi
  else rrc=NA; fi
  if [ "$rrc" = 0 ] && grep -Fq 'PASS: §16.13.7 separate semantic-leading-clock initializers' "$RUN_DIR/results/logs/$edition.stdout.log" && ! grep -Fq 'FAIL:' "$RUN_DIR/results/logs/$edition.stdout.log"; then pass=YES; else pass=NO; failed=1; fi
  printf '%s\t%s\t%s\t%s\n' "$edition" "$crc" "$rrc" "$pass" >> "$RUN_DIR/results/results.tsv"
done
date -u +%FT%TZ > "$RUN_DIR/results/end.utc"
cat "$RUN_DIR/results/results.tsv"
for f in "$RUN_DIR/results"/logs/*.stdout.log "$RUN_DIR/results"/logs/*.stderr.log; do [ -f "$f" ] || continue; echo "--- ${f##*/}"; cat "$f"; done
exit "$failed"
