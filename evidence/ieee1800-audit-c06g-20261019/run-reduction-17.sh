#!/usr/bin/env bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
D=tests/1800_audit/c06
E=evidence/ieee1800-audit-c06g-20261019/attempt-03
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
mkdir -p "$E"
for g in 2017 2023; do
  for f in "$D"/r06_17_?.sv; do b=$(basename "$f" .sv); o="$E/$b.$g"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" > "$o.compile.log" 2>&1; rc=$?; echo "$b g$g compile rc=$rc"; head -3 "$o.compile.log"
    if [ -f "$o.vvp" ]; then python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; rc=$?; echo "run rc=$rc"; head -4 "$o.run.log"; fi
  done
done
