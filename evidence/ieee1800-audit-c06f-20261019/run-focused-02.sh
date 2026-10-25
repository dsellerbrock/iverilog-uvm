#!/usr/bin/env bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c06
E=evidence/ieee1800-audit-c06f-20261019/attempt-03
mkdir -p "$E"
for g in 2017 2023; do
  for base in p06_23b_type_scalar p06_23c_type_cast p06_23d_generate_case p06_23e_type_aggregates; do
    exe="$E/$base.$g.vvp"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" "$D/$base.sv" > "$E/$base.$g.compile.log" 2>&1
    rc=$?; printf '\n%s -g%s compile rc=%s\n' "$base" "$g" "$rc"; cat "$E/$base.$g.compile.log"
    if [ -f "$exe" ]; then
      python3 scripts/run_with_timeout.py 60 -- "$VVP" "$exe" > "$E/$base.$g.run.log" 2>&1
      rc=$?; printf '%s -g%s run rc=%s\n' "$base" "$g" "$rc"; cat "$E/$base.$g.run.log"
    fi
  done
done
