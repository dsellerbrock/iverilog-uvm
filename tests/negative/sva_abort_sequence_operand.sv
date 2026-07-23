// The abort operators (accept_on/reject_on and sync_ variants, IEEE
// 1800-2017 16.12.9) are supported in this engine only with a boolean
// operand. A multi-cycle SEQUENCE operand aborts a temporal obligation
// the single-cycle lowering cannot represent, so it must be rejected with
// a loud diagnostic rather than silently miscompiled.
module sva_abort_sequence_operand;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;
  // `a ##1 b' is a two-cycle sequence -> not a boolean operand.
  bad: assert property (@(posedge clk) reject_on(c) (a ##1 b));
endmodule
