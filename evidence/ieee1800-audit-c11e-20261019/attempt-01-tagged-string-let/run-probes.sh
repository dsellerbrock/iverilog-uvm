#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c11
E=evidence/ieee1800-audit-c11e-20261019/attempt-01-tagged-string-let
for g in 2017 2023; do
  for f in p11_09a_tagged_str_let r11_09_wrong_tag; do
    o="$E/$f.$g"; rm -f "$o.vvp"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$D/$f.sv" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$f" "$g" "$rc"; cat "$o.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf '== %s g%s run rc=%s ==\n' "$f" "$g" "$rc"; cat "$o.run.log"
    fi
  done
  for f in "$D"/neg/n11_12_*.sv; do
    n=$(basename "$f" .sv); o="$E/$n.$g"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o /dev/null "$f" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$n" "$g" "$rc"; cat "$o.compile.log"
  done
done
