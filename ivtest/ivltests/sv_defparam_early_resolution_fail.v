// IEEE 1800-2017/2023 §23.10.4.2: the early and final resolutions differ.
module m;
  m1 n();
endmodule

module m1;
  parameter p = 2;
  defparam m.n.p = 1;
  initial $display(m.n.p);
  generate
    if (p == 1) begin : m
      m2 n();
    end
  endgenerate
endmodule

module m2;
  parameter p = 3;
endmodule
