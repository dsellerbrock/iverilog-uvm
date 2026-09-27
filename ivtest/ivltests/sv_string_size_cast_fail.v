// A size cast of a string-typed value is not an integral cast (IEEE
// 1800-2017/2023 6.24.1). Accepted only under -gcommercial-unsafe.
module test;
  string s = "AB";
  logic [15:0] v;
  initial v = 16'(s);
endmodule
