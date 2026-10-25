#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
E=evidence/ieee1800-audit-c11e-20261019/attempt-02-package-let-reduction
for g in 2017 2023; do
  for f in r11_12_pkg_simple r11_12_pkg_args r11_12_pkg_request_name r11_12_mod_simple; do
    o="$E/$f.$g"; rm -f "$o.vvp"
    if python3 scripts/run_with_timeout.py 30 -- "$IVL" -g"$g" -o "$o.vvp" "$E/$f.sv" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$f" "$g" "$rc"; cat "$o.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 30 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf '== %s g%s run rc=%s ==\n' "$f" "$g" "$rc"; cat "$o.run.log"
    fi
  done
done
