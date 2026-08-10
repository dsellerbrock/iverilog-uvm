// IEEE 1800-2017 16.10 + 16.5.1: a sequence local used inside a select
// remains per-attempt, while the selected DESIGN vector is read from the
// Preponed region.  The variable window forces the NFA local-slot path.
//
// vec toggles by NBA on every posedge.  At the only b tick its Preponed
// value is 0 and its post-NBA value is 1, so `!vec[x]' distinguishes a real
// sample from an Observed-region live read.  Before this regression's fix,
// x inside `vec[x]' was neither detected nor substituted and compilation
// left an unresolved/shared x in the guard.
module local_var_index_preponed_nfa_only;
  logic clk = 0, a = 0, b = 0;
  logic [3:0] vec = 0;
  int idx = 2;
  always #5 clk = ~clk;
  always @(posedge clk) vec <= ~vec;

  cv: cover property (@(posedge clk)
        (a, x = idx) ##[1:3] (b && !vec[x]));

  initial begin
    // First posedge changes vec 0->1. Capture x=2 on the second posedge,
    // which changes vec 1->0. At the third posedge, Preponed vec is 0;
    // the NBA changes it to 1 before the checker reaches Observed.
    @(negedge clk) a = 1;
    @(negedge clk) a = 0; b = 1;
    @(negedge clk) b = 0;
    repeat (2) @(negedge clk);
    $display("indexed-local cover=%0d (expect 1)", _ivl_sva0_cnt0);
    $finish(0);
  end
endmodule
