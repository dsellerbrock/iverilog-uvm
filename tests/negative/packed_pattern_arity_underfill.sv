// IEEE 1800-2017 10.9.2: an assignment pattern onto a packed dimension
// must supply exactly one element per position. Underfill used to be
// silently zero-extended (recovery D6).
module top;
  logic [7:0] x = '{2{1'b1}};
  initial $display("x=%b", x);
endmodule
