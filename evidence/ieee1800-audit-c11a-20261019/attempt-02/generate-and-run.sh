#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c11/neg
E=evidence/ieee1800-audit-c11a-20261019/attempt-02
mkdir -p "$D" "$E"
r(){ printf 'module m; real r = 5.5, q; int i; initial begin %s $display("OUT q=%%f i=%%0d r=%%f", q, i, r); end endmodule\n' "$2" > "$D/n11_real_$1.sv"; }
r mod 'q = r % 2.0;'
r modassign 'r %= 2.0;'
r bitand 'q = r & 1;'
r bitor 'q = r | 1;'
r bitxor 'q = r ^ 1;'
r bitnot 'q = ~r;'
r shl 'q = r << 1;'
r shr 'q = r >> 1;'
r ashl 'q = r <<< 1;'
r redand 'i = &r;'
r caseeq 'i = (r === 5.5);'
r wildeq 'i = (r ==? 5.5);'
r concat 'q = {r};'
r shlassign 'r <<= 1;'
r andassign 'r &= 1;'
for g in 2017 2023; do
  for f in "$D"/n11_real_*.sv; do
    b=$(basename "$f" .sv); o="$E/$b.$g"; rm -f "$o.vvp"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$b" "$g" "$rc"
    head -3 "$o.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf 'run rc=%s: ' "$rc"; cat "$o.run.log"
    fi
  done
done
