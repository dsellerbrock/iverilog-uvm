// A reduction operand of unary ! needs parentheses (IEEE 1800-2017/2023
// A.8.3). Accepted only under -gcommercial-unsafe.
module test;
  logic a, b, c;
  initial c = !&{a, b};
endmodule
