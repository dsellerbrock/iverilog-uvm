// A sequence combinator (`or'/`and') used as an operand of an
// implication. Legal per IEEE 1800-2017 A.2.10 (the antecedent is a
// sequence_expr) plus 16.9.5 (or/and produce one), but not
// representable here: sva_property_t's antecedent and consequent are
// flat step chains while a combinator is a tree.
//
// The point of this test is not the limitation -- it is that the
// limitation must be LOUD. With no grammar production the form died as
// a bare `syntax error', which desynchronizes the parser; inside a
// macro inside a generate block (exactly how OpenTitan's alert
// primitives write it) that desync attributed cascading "Invalid
// module item" and "Malformed statement" errors to unrelated, correct
// code further down the file. One construct presented as 39 errors.
module sva_comb_implication_operand;
  logic clk = 0, a = 0, b = 0, c = 0, d = 0;
  always #5 clk = ~clk;
  ap: assert property (@(posedge clk) (a ##1 b) or (c ##1 d) |-> c);
endmodule
