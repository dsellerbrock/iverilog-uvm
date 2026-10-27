#!/bin/bash
set -eu
D=tests/1800_audit/c11
l(){ printf '%s\n' "$2" > "$D/r11_12_decl_$1.sv"; }
l pkg 'package pk; let f(x)=x+1; endpackage module m; endmodule'
l pkg0 'package pk; let c=1; endpackage module m; endmodule'
l unit 'let f(x)=x+1; module m; endmodule'
l unit0 'let c=1; module m; endmodule'
l task 'module m; task t; let f(x)=x+1; endtask endmodule'
l task0 'module m; task t; let c=1; endtask endmodule'
l block 'module m; initial begin let f(x)=x+1; end endmodule'
l gen 'module m; generate if (1) begin: g let f(x)=x+1; end endgenerate endmodule'
l fn 'module m; function int ff(int v); let f(x)=x+1; return f(v); endfunction initial $display("F %0d", ff(1)); endmodule'
