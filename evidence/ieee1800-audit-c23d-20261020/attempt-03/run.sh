#!/bin/sh
set -u
ROOT=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
TIMEOUT=$ROOT/scripts/run_with_timeout.py
OUT=$ROOT/evidence/ieee1800-audit-c23d-20261020/attempt-03
for g in 2017 2023; do
  for name in extern_m extern_param; do
    case "$name" in
      extern_m) src=$ROOT/tests/1800_audit/c23/p23_04b_extern_m.sv ;;
      extern_param) src=$ROOT/tests/1800_audit/c23/p23_04c_extern_param.sv ;;
    esac
    exe=$OUT/$name.$g.vvp
    if python3 "$TIMEOUT" 45 -- "$IVL" -g"$g" -o "$exe" "$src" > "$OUT/$name.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '\n== %s -g%s compile rc=%s ==\n' "$name" "$g" "$rc"
    cat "$OUT/$name.$g.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 "$TIMEOUT" 45 -- "$VVP" "$exe" > "$OUT/$name.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf 'run rc=%s\n' "$rc"
      cat "$OUT/$name.$g.run.log"
    fi
  done
done
