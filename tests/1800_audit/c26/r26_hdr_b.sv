package A; typedef bit [7:0] byte_t; endpackage
module M (input A::byte_t a, output A::byte_t b);
  assign b = a;
endmodule
module top;
  wire [7:0] y;
  M m(8'h5A, y);
  initial #1 $display("HB %h", y);
endmodule
