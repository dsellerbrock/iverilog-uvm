package A; typedef bit [7:0] byte_t; endpackage
module M import A::byte_t; (input byte_t a, output byte_t b);
  assign b = a;
endmodule
module top;
  wire [7:0] y;
  M m(8'h5A, y);
  initial #1 $display("HA %h", y);
endmodule
