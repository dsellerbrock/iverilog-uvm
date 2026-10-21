#!/usr/bin/env bash
set -u
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
D=tests/1800_audit/c06
OUT=evidence/ieee1800-audit-c06d-20261019/reduction-attempt-02
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
mkdir -p "$D/neg" "$OUT"
T='typedef enum {X, Y} e_t; typedef struct {int a;} s_t; class K; endclass'
r(){ printf '%s\n%s\n' "$T" "$2" > "$D/r06_20_fwd_$1.sv"; }
r r1_enum 'module s #(type enum E = e_t); endmodule module m; s u(); endmodule'
r r2_param 'module s #(parameter type enum E = e_t); endmodule module m; s u(); endmodule'
r r3_struct 'module s #(type struct S = s_t); endmodule module m; s u(); endmodule'
r r4_class 'module s #(type class C = K); endmodule module m; s u(); endmodule'
r r5_plain 'module s #(type E = e_t); endmodule module m; s u(); endmodule'
r r6_classok 'class P #(type enum E = e_t); E v; endclass module m; P#(e_t) p = new; endmodule'
r r7_classneg 'class P #(type enum E = e_t); E v; endclass module m; P#(int) p = new; endmodule'
printf '%s\n' 'class K; endclass' 'module m; const K k = new; initial k = new; endmodule' > "$D/neg/n06_20_const_handle_reassign.sv"
printf 'HOST: %s\nCHECKOUT: %s\n' "$(uname -a)" "$(git rev-parse HEAD)"
printf 'COMPILER SOURCE: b9441bafbdb0b6b7413c09e0381845e69481391b\n'
shasum -a 256 "$IVL"
for g in 2017 2023; do
  for f in "$D"/r06_20_fwd_*.sv "$D"/neg/n06_20_const_handle_reassign.sv; do
    b=$(basename "$f" .sv)
    exe="$OUT/$b.$g.vvp"
    log="$OUT/$b.$g.compile.log"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" "$f" >"$log" 2>&1
    rc=$?
    printf '\n%s -g%s rc=%s\n' "$b" "$g" "$rc"
    cat "$log"
  done
done
