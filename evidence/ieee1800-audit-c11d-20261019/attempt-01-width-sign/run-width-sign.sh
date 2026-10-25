#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c11
E=evidence/ieee1800-audit-c11d-20261019/attempt-01-width-sign
for g in 2017 2023; do
  o="$E/p11_06b_width_sign.$g"; rm -f "$o.vvp"
  if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$D/p11_06b_width_sign.sv" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '== p11_06b_width_sign g%s compile rc=%s ==\n' "$g" "$rc"; cat "$o.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== p11_06b_width_sign g%s run rc=%s ==\n' "$g" "$rc"; cat "$o.run.log"
  fi
done
