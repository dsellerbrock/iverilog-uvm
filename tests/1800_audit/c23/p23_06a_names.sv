module cct(stim1, stim2); input stim1, stim2; mod amod(stim1), bmod(stim2); endmodule
module mod(in); input in; always @(posedge in) begin : keep logic hold; hold = in; end endmodule
module wave; logic stim1=0, stim2=0; cct a(stim1, stim2);
 initial begin :wave1 #100 fork :innerwave reg hold; join #150 begin stim1 = 1; end end
 initial begin #1 $display("HN %b", $root.wave.a.amod.in); #300 $display("HN2 %b %b", wave.a.stim1, $root.wave.a.bmod.in); end endmodule
module m23(); function void f(); $display("p::f"); endfunction endmodule
function int f(int y); return y+1; endfunction
package p; function void g(); $display("p::g"); endfunction endpackage
module tp; import p::*; int r; task automatic t; int x; x = f(1); r = x; endtask
 if (1) begin : b initial begin #1 f2(); end function void f2(); $display("top.b.f2"); endfunction end
 initial begin #2 t(); $display("TF %0d", r); end endmodule
module pm; package_dummy: ; endmodule
