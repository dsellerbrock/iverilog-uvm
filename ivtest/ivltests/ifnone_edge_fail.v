`timescale 1ns/1ns
module m(input clk, input d, output reg q); always @(posedge clk) q <= d;
  specify ifnone (posedge clk => (q : d)) = 1; endspecify
endmodule
module top; reg clk, d; wire q; m u(clk, d, q); endmodule
