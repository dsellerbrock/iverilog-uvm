module a;
  integer i;
  b a_b1();
endmodule
module b;
  integer i;
  c c1();
endmodule
module c;
  initial b.i = 7;
endmodule
module d;
  integer i;
  b d_b1();
endmodule
module top;
  a a();
  d d();
  initial begin
    #5 $display("%0d %0d", a.a_b1.i, d.d_b1.i);
    $finish;
  end
endmodule
