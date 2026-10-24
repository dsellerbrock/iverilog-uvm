#!/bin/bash
set -euo pipefail
REPO=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
EVDIR="$REPO/evidence/ieee1800-audit-c15a-20261020/attempt-06-current-main-events-semaphore"
BUILD=/tmp/a3-main-c41e-c15a-20261020-01
IVL="$BUILD/install/bin/iverilog"
VVP="$BUILD/install/bin/vvp"
PROBES="$EVDIR/input"
test -x "$IVL"
test -x "$VVP"
mkdir -p "$PROBES/neg" "$EVDIR/logs"
cp "$REPO/tests/1800_audit/c15/p15_03a_semaphore.sv" "$REPO/tests/1800_audit/c15/p15_05a_events.sv" "$REPO/tests/1800_audit/c15/r15_wait_order_fail.sv" "$PROBES/"
cp "$REPO/scripts/run_with_timeout.py" "$PROBES/"
printf 'compiler/vvp sha256:\n' > "$EVDIR/toolchain.sha256"
shasum -a 256 "$IVL" "$VVP" >> "$EVDIR/toolchain.sha256"
printf 'edition\tprobe\tcompile_rc\trun_rc\n' > "$EVDIR/results.tsv"
run_timed() { python3 "$PROBES/run_with_timeout.py" 20 -- "$@"; }
for g in 2017 2023; do
  for name in p15_03a_semaphore p15_05a_events r15_wait_order_fail; do
    log="$EVDIR/logs/$name-g$g.log"
    if run_timed "$IVL" -g"$g" -o "$EVDIR/$name-g$g.vvp" "$PROBES/$name.sv" > "$log" 2>&1; then crc=0; else crc=$?; fi
    rrc=NA
    if [ "$crc" -eq 0 ]; then
      if run_timed "$VVP" "$EVDIR/$name-g$g.vvp" >> "$log" 2>&1; then rrc=0; else rrc=$?; fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$g" "$name" "$crc" "$rrc" >> "$EVDIR/results.tsv"
  done
done
cat "$EVDIR/results.tsv"
