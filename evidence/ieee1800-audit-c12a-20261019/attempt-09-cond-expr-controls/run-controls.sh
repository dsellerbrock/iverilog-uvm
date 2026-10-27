#!/bin/bash
set -euo pipefail
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12a-20261019/attempt-09-cond-expr-controls
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
sha256sum "$IVL" "$VVP" >"$E/toolchain-sha256.txt"
H='typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int nv=0, y=1, z=0;'
t() { printf '%s\ninitial begin v=tagged Valid(5); %s $display("%s nv=%%0d", nv); end endmodule\n' "$H" "$2" "$1" >"$D/r12_06_$1.sv"; }
t h1 'nv = v matches tagged Valid .n ? n : -1;'
t h2 'nv = v matches tagged Invalid ? 1 : 2;'
t h3 'nv = v matches tagged Valid .n &&& n>3 ? n : -1;'
t h4 'nv = v matches tagged Valid .n &&& n>7 ? n : -1;'
t h5 'nv = y &&& (y>0) ? 1 : 2;'
t h6 'nv = y &&& z ? 1 : 2;'
shasum -a 256 "$D"/r12_06_h{1,2,3,4,5,6}.sv >"$E/sources.sha256"
overall=0
for g in 2017 2023; do
  for h in h1 h2 h3 h4 h5 h6; do
    f="$D/r12_06_$h.sv"
    o="$E/r12_06_$h.$g"
    if python3 scripts/run_with_timeout.py 180 -- "$IVL" -g"$g" -s m -o "$o.vvp" "$f" >"$o.compile.log" 2>&1; then
      printf '%s g%s compile rc=0\n' "$h" "$g"
      if python3 scripts/run_with_timeout.py 180 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1; then
        cat "$o.run.log"
      else
        rc=$?
        printf '%s g%s run rc=%s\n' "$h" "$g" "$rc"
        overall=1
      fi
    else
      rc=$?
      printf '%s g%s compile rc=%s\n' "$h" "$g" "$rc"
      head -3 "$o.compile.log"
      overall=1
    fi
  done
done
exit "$overall"
