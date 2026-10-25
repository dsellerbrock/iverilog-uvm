module top;
  logic a, b;
  uwire u;
  assign u = a;
  assign u = b;
  initial $display("%b", u);
endmodule
