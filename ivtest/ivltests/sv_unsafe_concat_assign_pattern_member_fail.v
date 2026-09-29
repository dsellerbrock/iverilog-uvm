// -gcommercial-unsafe types each '{...} in a packed-array concatenation, but
// a named pattern must still cover every member (IEEE 1800-2017/2023
// 10.9.2): report exactly that, with no cascade from the partial value.
module test;
  typedef struct packed { logic [3:0] a; logic [3:0] b; logic c; } s_t;
  parameter s_t [1:0] P = { '{a: 4'h1, b: 4'h2}, '{a: 4'h1, b: 4'h2, c: 1'b0} };
  initial $display("FAILED: %h", P);
endmodule
