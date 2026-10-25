#!/usr/bin/env bash
#SBATCH --job-name=a3-c07g-assign
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=logs/job-%j.out
set -uo pipefail

RUN_DIR="${SLURM_SUBMIT_DIR:-$(pwd)}"
IVL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/iverilog
VVP=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/vvp
SRC="$RUN_DIR/input/p07_10_4_assignment.sv"
OUT="$RUN_DIR/results"
mkdir -p "$OUT/logs"
date -u +%FT%TZ > "$OUT/start.utc"
hostname > "$OUT/host.txt"
uptime >> "$OUT/host.txt"
"$IVL" -V > "$OUT/iverilog-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$SRC" > "$OUT/SHA256SUMS"
printf 'edition\tcompile_rc\trun_rc\tstdout_match\n' > "$OUT/results.tsv"
overall=0

for edition in 2017 2023; do
  image="$OUT/p07_10_4_assignment-g$edition.vvp"
  if timeout --kill-after=2s 30s "$IVL" -g"$edition" -s p07_10_4_assignment -o "$image" "$SRC" > "$OUT/logs/compile-g$edition.stdout.log" 2> "$OUT/logs/compile-g$edition.stderr.log"; then
    crc=0
    if timeout --kill-after=2s 30s "$VVP" "$image" > "$OUT/logs/run-g$edition.stdout.log" 2> "$OUT/logs/run-g$edition.stderr.log"; then
      rrc=0
      if printf 'PASS\n' | cmp -s - "$OUT/logs/run-g$edition.stdout.log"; then match=YES; else match=NO; overall=1; fi
    else rrc=$?; match=RUN_FAILED; overall=1; fi
  else crc=$?; rrc=NA; match=COMPILE_FAILED; overall=1; fi
  printf '%s\t%s\t%s\t%s\n' "$edition" "$crc" "$rrc" "$match" >> "$OUT/results.tsv"
done

date -u +%FT%TZ > "$OUT/end.utc"
cat "$OUT/results.tsv"
exit "$overall"
