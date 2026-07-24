module sub; reg [3:0] v = 4'hA; endmodule
module chk(input [3:0] x); initial #1 if (x==4'hA) $display("PASS"); else $display("FAIL x=%h",x); endmodule
module top; sub u1(); sub u2(); bind top.u1 chk c1(.x(u1.v)); endmodule
