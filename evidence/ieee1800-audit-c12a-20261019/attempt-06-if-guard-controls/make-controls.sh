#!/bin/bash
set -eu
D=tests/1800_audit/c12
H='typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int hit=0, y=1, z=0;'
c(){ printf '%s\ninitial begin v=tagged Valid(5); %s $display("%s hit=%%0d", hit); end endmodule\n' "$H" "$2" "$1" > "$D/r12_06_$1.sv"; }
c g1 'if (v matches tagged Valid .n) hit=n; else hit=21;'
c g2 'if (y &&& (y>0)) hit=1; else hit=2;'
c g3 'if (y &&& z) hit=1; else hit=2;'
c g4 'hit = (v matches tagged Valid .n &&& n>3) ? n : -1;'
c g5 'if (v matches tagged Valid .n &&& (n==5)) hit=20; else hit=21;'
