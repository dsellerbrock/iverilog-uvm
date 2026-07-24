module sub; reg [3:0] v = 4'h5; endmodule
module chk(input [3:0] x); initial #1 $display("HIT %h", x); endmodule
module top; sub u1(); sub u2();
  bind sub : u1, u2 chk c1(.x(v));
  initial #2 $display("PASS");
endmodule
