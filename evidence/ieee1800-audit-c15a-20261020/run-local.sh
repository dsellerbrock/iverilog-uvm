#!/bin/bash
set -u
ROOT=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
OUT="$ROOT/evidence/ieee1800-audit-c15a-20261020"
IVL=${IVL:-/opt/homebrew/bin/iverilog}
VVP=${VVP:-/opt/homebrew/bin/vvp}
TIMEOUT="$ROOT/scripts/run_with_timeout.py"
SRC="$ROOT/tests/1800_audit/c15"
mkdir -p "$OUT/logs"
printf 'edition\tprobe\tcompile_rc\trun_rc\texpected\n' > "$OUT/results.tsv"
run_timed() { python3 "$TIMEOUT" 20 -- "$@"; }
for g in 2017 2023; do
  log="$OUT/logs/p15_04a-g$g.log"
  run_timed "$IVL" -g"$g" -o "$OUT/p15_04a-g$g.vvp" "$SRC/p15_04a_mailbox.sv" >"$log" 2>&1
  crc=$?
  rrc=NA
  if [ "$crc" -eq 0 ]; then
    run_timed "$VVP" "$OUT/p15_04a-g$g.vvp" >>"$log" 2>&1
    rrc=$?
  fi
  printf '%s\tpositive\t%s\t%s\tRESULT pass=16 fail=0\n' "$g" "$crc" "$rrc" >> "$OUT/results.tsv"

  log="$OUT/logs/r15_get_mismatch-g$g.log"
  run_timed "$IVL" -g"$g" -o "$OUT/r15_get_mismatch-g$g.vvp" "$SRC/r15_get_mismatch.sv" >"$log" 2>&1
  crc=$?
  rrc=NA
  if [ "$crc" -eq 0 ]; then
    run_timed "$VVP" "$OUT/r15_get_mismatch-g$g.vvp" >>"$log" 2>&1
    rrc=$?
  fi
  printf '%s\truntime_mismatch\t%s\t%s\tno SURVIVED; runtime diagnostic expected\n' "$g" "$crc" "$rrc" >> "$OUT/results.tsv"

  for neg in n15_param_put_int n15_param_get_int; do
    log="$OUT/logs/$neg-g$g.log"
    run_timed "$IVL" -g"$g" -o "$OUT/$neg-g$g.vvp" "$SRC/neg/$neg.sv" >"$log" 2>&1
    crc=$?
    printf '%s\t%s\t%s\tNA\tcompile reject expected\n' "$g" "$neg" "$crc" >> "$OUT/results.tsv"
  done
done
shasum -a 256 "$IVL" "$VVP" > "$OUT/toolchain.sha256"
sw_vers > "$OUT/host.txt"
cat "$OUT/results.tsv"
