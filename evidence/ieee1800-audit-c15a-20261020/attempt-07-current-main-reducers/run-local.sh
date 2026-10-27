#!/bin/bash
set -euo pipefail
REPO=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
OUT="$REPO/evidence/ieee1800-audit-c15a-20261020/attempt-07-current-main-reducers"
IVL=/tmp/a3-main-c41e-c15a-20261020-01/install/bin/iverilog
VVP=/tmp/a3-main-c41e-c15a-20261020-01/install/bin/vvp
printf 'edition\tprobe\tcompile_rc\trun_rc\n' > "$OUT/results.tsv"
run_timed() { python3 "$OUT/input/run_with_timeout.py" 20 -- "$@"; }
for g in 2017 2023; do
  for name in r15_event_arg_implicit_input r15_event_arg_explicit_input r15_wait_order r15_wait_order_fail; do
    log="$OUT/logs/$name-g$g.log"
    if run_timed "$IVL" -g"$g" -o "$OUT/$name-g$g.vvp" "$OUT/input/$name.sv" > "$log" 2>&1; then crc=0; else crc=$?; fi
    rrc=NA
    if [ "$crc" -eq 0 ]; then
      if run_timed "$VVP" "$OUT/$name-g$g.vvp" >> "$log" 2>&1; then rrc=0; else rrc=$?; fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$g" "$name" "$crc" "$rrc" >> "$OUT/results.tsv"
  done
done
shasum -a 256 "$IVL" "$VVP" > "$OUT/toolchain.sha256"
cat "$OUT/results.tsv"
