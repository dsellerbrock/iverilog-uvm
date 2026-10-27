#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c11
E=evidence/ieee1800-audit-c11a-20261019/attempt-01
mkdir -p "$E"
for g in 2017 2023; do
  for f in p11_04a_arith p11_04b_compare; do
    o="$E/$f.$g"
    rm -f "$o.vvp"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$D/$f.sv" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$f" "$g" "$rc"
    head -4 "$o.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf 'run rc=%s\n' "$rc"
      cat "$o.run.log"
    fi
  done
  for f in "$D"/neg/n11_0[34]_*.sv; do
    b=$(basename "$f" .sv); o="$E/$b.$g"
    rm -f "$o.vvp"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s expected-error compile rc=%s ==\n' "$b" "$g" "$rc"
    head -4 "$o.compile.log"
  done
done
