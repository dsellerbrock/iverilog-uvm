// Companion negative to sv_assert_liveness_no_action.v: a REAL, non-empty
// pass action on a liveness operator must still be refused loudly (IEEE
// 1800-2017 16.14.6) -- the fix for the action-less bare `;' form must
// not also swallow a genuine pass action.
module main;
  bit clk = 0;
  bit x = 0;
  int hits = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  ap: assert property (s_eventually(x)) hits++;
endmodule
