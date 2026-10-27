#!/bin/bash
set -eu
D=tests/1800_audit/c12
H='typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int hit=0, x=5, y=1;'
w(){ printf '%s\ninitial begin v=tagged Valid(5); %s $display("%s hit=%%0d", hit); end endmodule\n' "$H" "$3" "$1" > "$D/r12_06_$1.sv"; }
w f1 x 'case (v) matches tagged Valid .n &&& (n>3): hit=2; default: hit=3; endcase'
w f2 x 'case (v) matches tagged Valid .n &&& n>3: hit=2; default: hit=3; endcase'
w f3 x 'case (v) matches tagged Valid .n: hit=n; endcase'
w f4 x 'case (v) matches tagged Valid .* &&& (y>0): hit=2; default: hit=3; endcase'
w f5 x 'case (x) matches 5 &&& (y>0): hit=2; default: hit=3; endcase'
w f6 x 'case (v) matches tagged Valid .n &&& (n>7): hit=1; tagged Valid .n &&& (n>3): hit=2; default: hit=3; endcase'
w f7 x 'if (v matches tagged Valid .n &&& n==5) hit=20; else hit=21;'
