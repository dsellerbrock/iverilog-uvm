module top;
  struct { logic a; logic [3:0] b; } v;
  assign v = '{1'b1, 4'h3};
  initial #1 $display("%b %h", v.a, v.b);
endmodule
