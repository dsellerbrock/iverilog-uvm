// NEG-DIAG: is supported only with a boolean operand
// NEG-DIAG-COUNT: 1
// IEEE 1800-2023 16.9.2: `put[->1]' is a goto-repetition sequence, not a
// boolean. The `always' lowering folds only a single boolean, so it must
// refuse this operand instead of silently checking `put' at every tick
// (#2672: the repetition used to be dropped).
module sva_goto_operand_not_boolean;
  bit clk = 0, put;
  always #5 clk = ~clk;
  bad: assert property (@(posedge clk) always put[->1]);
endmodule
