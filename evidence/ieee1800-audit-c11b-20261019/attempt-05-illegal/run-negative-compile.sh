#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
D=tests/1800_audit/c11/neg
E=evidence/ieee1800-audit-c11b-20261019/attempt-05-illegal
for g in 2017 2023; do
  for f in "$D"/n11_14_*.sv; do
    b=$(basename "$f" .sv)
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o /dev/null "$f" > "$E/$b.$g.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$b" "$g" "$rc"
    cat "$E/$b.$g.log"
  done
done
