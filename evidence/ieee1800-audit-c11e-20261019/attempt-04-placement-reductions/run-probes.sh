#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c11
E=evidence/ieee1800-audit-c11e-20261019/attempt-04-placement-reductions
for g in 2017 2023; do
  for f in "$D/p11_09b_no_pkg.sv" "$D"/r11_12_decl_*.sv; do
    n=$(basename "$f" .sv); o="$E/$n.$g"
    if python3 scripts/run_with_timeout.py 30 -- "$IVL" -g"$g" -o "$o.vvp" "$f" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$n" "$g" "$rc"; cat "$o.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 30 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf '== %s g%s run rc=%s ==\n' "$n" "$g" "$rc"; cat "$o.run.log"
    fi
  done
done
