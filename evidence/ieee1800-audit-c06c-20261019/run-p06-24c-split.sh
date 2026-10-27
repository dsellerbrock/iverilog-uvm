#!/usr/bin/env bash
set -u
D=tests/1800_audit/c06
E=evidence/ieee1800-audit-c06c-20261019
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
mkdir -p "$D/neg" "$E"
echo "HOST: $(uname -a)"
echo "SOURCE COMMIT: $(git rev-parse HEAD)"
echo "IVERILOG: $IVL"
"$IVL" -V 2>&1 | head -2
shasum -a 256 "$IVL" "$VVP"

python3 - <<'PY'
from pathlib import Path
tests = Path("tests/1800_audit/c06")
positives = {
    "r06_24c_s2p.sv": r"""module t;
typedef struct {byte a; byte b;} s_t; s_t s; typedef bit [15:0] p16_t; p16_t v;
initial begin s.a=8'h12; s.b=8'h34; v=p16_t'(s); $display("s2p %h (expect 1234)",v); end
endmodule
""",
    "r06_24c_p2s.sv": r"""module t;
typedef struct {byte a; byte b;} s_t; s_t s; typedef bit [15:0] p16_t; p16_t v;
initial begin s=s_t'(16'h1234); $display("p2s %h %h (expect 12 34)",s.a,s.b); end
endmodule
""",
    "r06_24c_p2ua.sv": r"""module t;
typedef byte b4_t[4]; b4_t ba;
initial begin ba=b4_t'(32'h01020304); $display("p2ua %0d %0d (expect 1 4)",ba[0],ba[3]); end
endmodule
""",
    "r06_24c_ua2p.sv": r"""module t;
typedef byte b4_t[4]; b4_t ba; int iv;
initial begin ba='{1,2,3,4}; iv=int'(ba); $display("ua2p %h (expect 01020304)",iv); end
endmodule
""",
    "r06_24c_q2str.sv": r"""module t;
byte dq[$]; string str;
initial begin dq.push_back("A"); dq.push_back("B"); str=string'(dq); $display("q2str %s (expect AB)",str); end
endmodule
""",
    "r06_24c_str2q.sv": r"""module t;
typedef byte q_t[$]; q_t dq; string str="AB";
initial begin dq=q_t'(str); $display("str2q %0d %0d %0d (expect 2 65 66)",dq.size(),dq[0],dq[1]); end
endmodule
""",
    "r06_24c_da.sv": r"""module t;
typedef byte da_t[]; da_t da; int iv;
initial begin da=da_t'(32'h01020304); $display("p2da %0d %0d (expect 4 1)",da.size(),da[0]); iv=int'(da); $display("da2p %h (expect 01020304)",iv); end
endmodule
""",
    "r06_24c_s2q.sv": r"""module t;
typedef struct {byte length; shortint address; byte payload[]; byte chksum;} Packet; typedef byte q_t[$]; Packet pk; q_t ch;
initial begin pk.length=2; pk.address=16'h1234; pk.payload='{8'hAA,8'hBB}; pk.chksum=8'h11; ch=q_t'(pk); $display("s2q %0d %0h %0h %0h %0h (expect 6 2 12 34 aa)",ch.size(),ch[0],ch[1],ch[2],ch[3]); end
endmodule
""",
    "r06_24c_q2s.sv": r"""module t;
typedef struct {byte length; shortint address; byte payload[]; byte chksum;} Packet; typedef byte q_t[$]; Packet rk; q_t ch;
initial begin ch='{2,8'h12,8'h34,8'hAA,8'hBB,8'h11}; rk=Packet'(ch); $display("q2s %0d %0h %0d %0h (expect 2 1234 2 11)",rk.length,rk.address,rk.payload.size(),rk.chksum); end
endmodule
""",
}
negatives = {
    "n06_24_struct24_to_int.sv": "module m; struct {bit[7:0] a; shortint b;} a; int b; initial b=int'(a); endmodule\n",
    "n06_24_int_to_struct33.sv": "module m; typedef struct {byte a[]; bit b;} dest_t; int a; dest_t b; initial b=dest_t'(a); endmodule\n",
    "n06_24_assoc_dest.sv": "module m; typedef int aa_t[int]; aa_t aa; int x[2]; initial aa=aa_t'(x); endmodule\n",
    "n06_24_size_zero.sv": "module m; initial begin int x; x=0'(5); end endmodule\n",
    "n06_24_size_neg.sv": "module m; parameter N=-1; initial begin int x; x=N'(5); end endmodule\n",
}
for name, source in positives.items():
    (tests / name).write_text(source)
for name, source in negatives.items():
    (tests / "neg" / name).write_text(source)
PY

for g in 2017 2023; do
  for f in "$D"/r06_24c_*.sv; do
    b=$(basename "$f" .sv); o="$E/$b.$g"; rm -f "$o.vvp"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" >"$o.compile.log" 2>&1; rc=$?
    echo "== $b g$g compile rc=$rc"; cat "$o.compile.log"
    if [ -f "$o.vvp" ]; then
      python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1; rc=$?
      echo "run rc=$rc"; cat "$o.run.log"
    else
      echo "run rc=not-run"
    fi
  done
  for f in "$D"/neg/n06_24_*.sv; do
    b=$(basename "$f" .sv); o="$E/$b.$g"; rm -f "$o.vvp"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$f" >"$o.compile.log" 2>&1; rc=$?
    echo "== $b g$g compile rc=$rc"; cat "$o.compile.log"
    if [ -f "$o.vvp" ]; then
      python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1; rc=$?
      echo "run rc=$rc"; cat "$o.run.log"
    else
      echo "run rc=not-run"
    fi
  done
done
