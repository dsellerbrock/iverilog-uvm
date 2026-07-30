// IEEE 1800-2017 10.9.2: '{2{4'h5}} onto logic[7:0] is 2 elements for
// 8 positions — an arity error. It used to compile to the silent
// wrong constant 8'h03 (recovery D6).
module top;
  logic [7:0] x = '{2{4'h5}};
  initial $display("x=%h", x);
endmodule
