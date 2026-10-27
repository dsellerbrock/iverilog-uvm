module top;
  wire struct { logic a; logic [3:0] b; } w;
  assign w = '{1'b1, 4'h3};
  initial #1 $display("%b %h", w.a, w.b);
endmodule
