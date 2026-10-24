#!/usr/bin/env bash
set -uo pipefail

IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c06
E=evidence/ieee1800-audit-c06b-20261019/step3
mkdir -p "$E"

cat > "$D/r06_19k_bare_forms.sv" <<'SV'
module t;
  typedef enum {red, green, blue, yellow} Colors;
  typedef enum logic [3:0] {Z0='z, X1='x} E4;
  typedef enum bit [3:0] {ONES='1, ZERO='0} E2;
  typedef struct { Colors col; } st_t;
  st_t st;
  Colors c;
  initial begin
    c = green;
    st.col = blue;
    $display("K1 plain: first=%0d next=%0d last=%0d name=%s", c.first, c.next, c.last, c.name);
    $display("K2 struct bare: first=%0d next=%0d name=%s", st.col.first, st.col.next, st.col.name);
    $display("K3 struct explicit: first=%0d next=%0d name=%s", st.col.first(), st.col.next(), st.col.name());
    $display("K5 values: ONES=%b ZERO=%b Z0=%b X1=%b", ONES, ZERO, Z0, X1);
  end
endmodule
SV

t() {
  printf 'module t; typedef enum {red, green, blue} Colors; Colors c;\n initial begin c = green; $display("%s => %%%s", %s); end endmodule\n' "$1" "$2" "$3" > "$D/r06_19l_$1.sv"
}
t len 0d 'c.name.len()'
t upper s 'c.name.toupper()'
t eqlit b 'c.name == "green"'
t lenbare 0d 'c.name.len'
t nextname s 'c.next.name'
t nextname2 s 'c.next().name()'

for g in 2017 2023; do
  for f in "$D"/r06_19k_*.sv "$D"/r06_19l_*.sv; do
    b=$(basename "$f" .sv)
    o="$E/$b.$g"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" >"$o.compile.log" 2>&1
    rc=$?
    echo "== $b g$g compile_rc=$rc"
    cat "$o.compile.log"
    if [ -f "$o.vvp" ]; then
      python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1
      rc=$?
      echo "run_rc=$rc"
      cat "$o.run.log"
    fi
  done
done
