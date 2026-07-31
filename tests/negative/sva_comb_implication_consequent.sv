// The mirror case: a combinator as the CONSEQUENT of an implication.
// Same representation limit, same requirement that it be loud rather
// than a bare syntax error. See sva_comb_implication_operand.sv.
module sva_comb_implication_consequent;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;
  ap: assert property (@(posedge clk) a |-> (b ##1 c) or (b ##1 b));
endmodule
