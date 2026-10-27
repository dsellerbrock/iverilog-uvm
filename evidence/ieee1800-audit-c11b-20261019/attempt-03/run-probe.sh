#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c11
E=evidence/ieee1800-audit-c11b-20261019/attempt-03
mkdir -p "$E"
for g in 2017 2023; do
  o="$E/p11_04d.$g"; rm -f "$o.vvp"
  if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$D/p11_04d_cat_inside_stream.sv" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '== p11_04d_cat_inside_stream g%s compile rc=%s ==\n' "$g" "$rc"
  head -6 "$o.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf 'run rc=%s\n' "$rc"; cat "$o.run.log"
  fi
done
