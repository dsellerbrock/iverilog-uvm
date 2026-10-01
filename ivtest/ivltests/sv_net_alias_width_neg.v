// An alias joins nets of the same width only (IEEE 1800-2017/2023 23.3.1).
module top;
  wire [3:0] a;
  wire [7:0] b;
  alias a = b;
endmodule
