// M9C-live negative: the nexttime index shall be a non-negative integer constant
// expression (IEEE 1800-2023 16.12.10); a negative index must be rejected.
// (Was m9c_nexttime_sequence_operand, which wrongly required a legal sequence operand
// to be rejected; see docs/conformance/IEEE_RULINGS.md, #3845.)
// NEG-DIAG: nexttime index -1 is negative
module top; logic clk=0,a,b;
  assert property (@(posedge clk) nexttime[-1] a);
endmodule
