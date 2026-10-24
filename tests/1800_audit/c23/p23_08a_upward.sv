module a; integer i; b a_b1(); endmodule
module b; integer i; c b_c1(), b_c2(); initial #10 b_c1.i = 2; endmodule
module c; integer i; initial begin i = 1; b.i = 1; end endmodule
module d; integer i; b d_b1();
 initial begin #5 a.i = 1; d.i = 5; a.a_b1.i = 2; d.d_b1.i = 6; a.a_b1.b_c1.i = 3; d.d_b1.b_c1.i = 7; a.a_b1.b_c2.i = 4; d.d_b1.b_c2.i = 8;
  #15 $display("UP %0d %0d %0d %0d %0d %0d %0d %0d", a.i, d.i, a.a_b1.i, d.d_b1.i, a.a_b1.b_c1.i, d.d_b1.b_c1.i, a.a_b1.b_c2.i, d.d_b1.b_c2.i); end endmodule
