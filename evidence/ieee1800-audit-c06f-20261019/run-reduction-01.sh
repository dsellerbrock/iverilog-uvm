#!/usr/bin/env bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
E=evidence/ieee1800-audit-c06f-20261019/attempt-02
mkdir -p "$E"
for g in 2017 2023; do
  exe="$E/r06_23b_no_generate.$g.vvp"
  python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" tests/1800_audit/c06/r06_23b_no_generate.sv > "$E/r06_23b_no_generate.$g.compile.log" 2>&1
  rc=$?; printf 'compile -g%s rc=%s\n' "$g" "$rc"; cat "$E/r06_23b_no_generate.$g.compile.log"
  if [ -f "$exe" ]; then
    python3 scripts/run_with_timeout.py 60 -- "$VVP" "$exe" > "$E/r06_23b_no_generate.$g.run.log" 2>&1
    rc=$?; printf 'run -g%s rc=%s\n' "$g" "$rc"; cat "$E/r06_23b_no_generate.$g.run.log"
  fi
done
