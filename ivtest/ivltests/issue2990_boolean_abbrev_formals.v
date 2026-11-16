// Legal controls for IEEE 1800-2023 16.8.1: a typed Boolean formal or an
// untyped formal may be a goto/nonconsecutive operand, and a sequence
// formal may be used as a sequence.
module issue2990_boolean_abbrev_formals;
  bit clk, a, b;
  sequence s(bit arg); arg[->1]; endsequence
  sequence u(arg); arg[=1]; endsequence
  sequence t(sequence arg); arg ##1 b; endsequence
  property p(sequence q); @(posedge clk) q |-> b[->1]; endproperty
  cover property (@(posedge clk) s(a));
  cover property (@(posedge clk) u(a));
  cover property (@(posedge clk) t(a));
  assert property (p(a));
  initial begin #5 $display("PASSED"); $finish; end
endmodule
