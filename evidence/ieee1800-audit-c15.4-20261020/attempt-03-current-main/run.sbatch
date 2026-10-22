#!/usr/bin/env bash
#SBATCH --job-name=a3-c15-mailbox-mismatch
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
mkdir -p "$RUN_DIR/results/logs"
hostname > "$RUN_DIR/results/host.txt"
uptime >> "$RUN_DIR/results/host.txt"
"$IVL" -V > "$RUN_DIR/results/iverilog-version.txt" 2>&1
"$VVP" -V > "$RUN_DIR/results/vvp-version.txt" 2>&1
sha256sum "$IVL" "$VVP" "$RUN_DIR/input/p15_04_mailbox_dynamic_type.sv" > "$RUN_DIR/results/SHA256SUMS"
printf 'edition\tcompile_rc\trun_rc\n' > "$RUN_DIR/results/results.tsv"
failed=0
for edition in 2017 2023; do
  name="mailbox-mismatch-$edition"
  binary="$RUN_DIR/scratch/$name.vvp"
  mkdir -p "$RUN_DIR/scratch"
  if /usr/bin/time -f '%e %M' -o "$RUN_DIR/results/logs/$name.compile.time" timeout --kill-after=2s 30s "$IVL" -B "$IVL_ROOT/lib/ivl" "-g$edition" -gno-icarus-misc -gno-xtypes -s p15_04_mailbox_dynamic_type -o "$binary" "$RUN_DIR/input/p15_04_mailbox_dynamic_type.sv" > "$RUN_DIR/results/logs/$name.compile.log" 2>&1; then crc=0; else crc=$?; failed=1; fi
  if [ "$crc" -eq 0 ]; then
    if /usr/bin/time -f '%e %M' -o "$RUN_DIR/results/logs/$name.run.time" timeout --kill-after=2s 30s "$VVP" -n "$binary" > "$RUN_DIR/results/logs/$name.stdout.log" 2>&1; then rrc=0; else rrc=$?; failed=1; fi
  else rrc=NA; fi
  printf '%s\t%s\t%s\n' "$edition" "$crc" "$rrc" >> "$RUN_DIR/results/results.tsv"
done
date -u +%FT%TZ > "$RUN_DIR/results/end.utc"
cat "$RUN_DIR/results/results.tsv"
for f in "$RUN_DIR/results"/logs/*.log; do [ -f "$f" ] || continue; echo "--- ${f##*/}"; cat "$f"; done
exit "$failed"
