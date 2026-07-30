// IEEE 1800-2017 10.9.2: nested pattern '{2{'{2{1'b1}}}} onto
// logic[1:0][3:0] underfills the inner 4-bit dimension with 2
// elements. Used to compile to the silent wrong constant 8'h0F
// (recovery D6).
module top;
  logic [1:0][3:0] y = '{2{'{2{1'b1}}}};
  initial $display("y=%b", y);
endmodule
