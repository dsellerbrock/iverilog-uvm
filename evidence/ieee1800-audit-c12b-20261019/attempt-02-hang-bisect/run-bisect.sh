#!/bin/bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12b-20261019/attempt-02-hang-bisect
write_probe() {
  name=$1; expr=$2
  printf 'module m; int cnt=0, sum=0, n=0, off=1, s=0; logic xc=1\047bx; logic [3:0] xr=4\047bx; logic [7:0] tmp=8\047hB6; int q[$]=\047{3,4,5}; int aa[string]; string kk;\ninitial begin %s $display("%s cnt=%%0d sum=%%0d s=%%0d", cnt, sum, s); end endmodule\n' "$expr" "$name" > "$D/r12_07_diag_$name.sv"
}
write_probe x_for 'for (int i=0;xc;i++) begin cnt++; if (cnt>5) break; end'
write_probe x_repeat 'repeat (xr) begin cnt++; if (cnt>5) break; end'
write_probe noexpr 'for (int i=0;;i++) begin if (i==3) break; cnt++; end'
write_probe forever 'forever begin cnt++; if (cnt==3) break; end'
write_probe while_sh 'while (tmp) begin if (tmp[0]) cnt++; tmp>>=1; end'
write_probe do_assoc 'aa["x"]=1; aa["y"]=2; if (aa.first(kk)) do cnt+=aa[kk]; while (aa.next(kk));'
write_probe fork_loc 'fork begin for (int i=0;i<3;i++) #1 sum+=1; end begin for (int i=0;i<3;i++) #1 sum+=10; end join'
write_probe multi 'for (int c=0,d=0,j=0;j*c<125 && j<4;j++,c++) s++;'
write_probe queue 'foreach (q[i]) cnt+=q[i]*i;'
printf '%s\n' "$(uname -a)" > "$E/host.txt"
git rev-parse HEAD > "$E/head.txt"
shasum -a 256 "$IVL" "$VVP" > "$E/toolchain-sha256.txt"
for g in 2017 2023; do
  for f in "$D"/r12_07_diag_*.sv; do
    name=$(basename "$f" .sv); o="$E/$name.$g"
    if ~/codex-supervisor/localrun 10 "$IVL" -g"$g" -o "$o.vvp" "$f" >"$o.compile.log" 2>&1; then
      printf '%s g%s compile rc=0\n' "$name" "$g"
      if ~/codex-supervisor/localrun 10 "$VVP" "$o.vvp" >"$o.run.log" 2>&1; then tail -8 "$o.run.log"; else rc=$?; printf '%s g%s run rc=%s\n' "$name" "$g" "$rc"; cat "$o.run.log"; fi
    else rc=$?; printf '%s g%s compile rc=%s\n' "$name" "$g" "$rc"; head -4 "$o.compile.log"; fi
  done
done
