// A concatenation operand is not an assignment-like context, so an untyped
// assignment pattern inside it has no type (IEEE 1800-2017/2023 10.9).
// Only -gcommercial-unsafe accepts this; see sv_unsafe_concat_assign_pattern.
module test;
  typedef struct packed { logic [3:0] a; logic [3:0] b; } pair_t;
  parameter pair_t [1:0] P = { '{a: 4'h1, b: 4'h2}, '{a: 4'h3, b: 4'h4} };
  initial $display("FAILED: %h", P);
endmodule
