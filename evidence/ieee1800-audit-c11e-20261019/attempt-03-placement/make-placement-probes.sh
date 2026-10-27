#!/bin/bash
set -eu
D=tests/1800_audit/c11
l(){ printf '%s\n' "$2" > "$D/r11_12_let_$1.sv"; }
l unit 'let f(x)=x+1; module m; initial $display("U %0d", f(1)); endmodule'
l gen 'module m; generate if (1) begin: g let f(x)=x+1; initial $display("G %0d", f(1)); end endgenerate endmodule'
l task 'module m; task t; let f(x)=x+1; $display("T %0d", f(1)); endtask initial t; endmodule'
l block 'module m; initial begin let f(x)=x+1; $display("B %0d", f(1)); end endmodule'
l iface 'interface i; let f(x)=x+1; initial $display("I %0d", f(1)); endinterface module m; i ii(); endmodule'
l prog 'program p; let f(x)=x+1; initial $display("P %0d", f(1)); endprogram'
l pkg 'package pk; let f(x)=x+1; endpackage module m; import pk::*; initial $display("K %0d", f(1)); endmodule'
l pkgq 'package pk; let f(x)=x+1; endpackage module m; initial $display("Q %0d", pk::f(1)); endmodule'
