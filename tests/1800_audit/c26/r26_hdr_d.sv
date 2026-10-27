package A; typedef bit [7:0] byte_t; endpackage
module M import A::*; #(WIDTH = 8) (input [WIDTH-1:0] data, output byte_t b);
  assign b = data;
endmodule
module top;
  wire [7:0] y;
  M m(8'h5A, y);
  initial #1 $display("HD %h", y);
endmodule
