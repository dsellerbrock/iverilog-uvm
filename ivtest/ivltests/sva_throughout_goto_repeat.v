// `g throughout b[->n]' was silently lowered to `g && b' -- it checked a
// DIFFERENT property than the one written, and reported violations that
// never happened.
//
// pform_sva_goto_repeat records goto (`b[->m:n]') and nonconsecutive
// (`b[=m:n]') repetition ONLY in rep_kind/rep_lo/rep_hi; delay_lo and
// delay_hi stay at the plain 0/0 of the boolean being repeated.
// sva_chain_fixed_len_ tested delay_lo/delay_hi/rep_tail but not
// rep_kind, so `b[->1]' classified as a FIXED chain of length 1. That
// sent `throughout' down the legacy fixed-length lowering, whose
// emitted steps never copy the repetition fields -- so the repetition
// vanished and the property became a one-cycle conjunction.
//
// `1 throughout b[->1]' has a constant-true invariant and therefore
// cannot fail under any trace. Before the fix it failed SEVEN times.
//
// The fixed-length forms must be untouched: `g throughout (a ##1 b)'
// still takes the legacy lowering and must still catch a dropped
// invariant. Both directions are checked here, because a fix that
// merely silenced the goto case by disabling `throughout' would pass a
// one-sided test.
module sva_throughout_goto_repeat;

  logic clk = 0;
  logic b = 0, g = 1, a = 0, c = 0;
  int   fail_thru = 0, fail_goto = 0, fail_fixed = 0;
  int   errors = 0;

  always #5 clk = ~clk;

  // Constant-true invariant over a goto repetition: can never fail.
  A_thru: assert property (@(posedge clk) 1 throughout b[->1])
     else fail_thru = fail_thru + 1;

  // Control: the bare goto repetition, which also never fails here.
  A_goto: assert property (@(posedge clk) b[->1])
     else fail_goto = fail_goto + 1;

  // Fixed-length throughout: MUST still detect a dropped invariant.
  // `a' and `c' are held high for the whole of phases 2 and 3, so the
  // sequence `a ##1 c' matches at every tick and the only thing that can
  // make this fire is `g' going low. (An unguarded sequence property has
  // to match at EVERY tick, so a sequence that merely fails to start
  // would fire constantly and say nothing about `throughout'. Guarding
  // with an implication is not an option here: `throughout' in a
  // consequent is a separate unsupported construct.)
  A_fixed: assert property (@(posedge clk) g throughout (a ##1 c))
     else fail_fixed = fail_fixed + 1;

  initial begin
    // Phase 1: let the goto assertions run, then satisfy them.
    repeat (3) @(posedge clk);
    b <= 1'b1; @(posedge clk); b <= 1'b0;
    repeat (3) @(posedge clk);

    if (fail_thru != 0) begin
      $display("FAIL: `1 throughout b[->1]' reported %0d violations; a", fail_thru);
      $display("      constant-true invariant cannot fail under any trace");
      errors = errors + 1;
    end
    if (fail_goto != 0) begin
      $display("FAIL: bare b[->1] reported %0d violations", fail_goto);
      errors = errors + 1;
    end

    // Phase 2: sequence matching every tick, invariant HELD -> no fail.
    g <= 1'b1; a <= 1'b1; c <= 1'b1;
    repeat (4) @(posedge clk);
    fail_fixed = 0;                     // ignore the phase-1 startup window
    repeat (3) @(posedge clk);
    if (fail_fixed != 0) begin
      $display("FAIL: fixed-length throughout fired %0d times with the", fail_fixed);
      $display("      invariant held throughout");
      errors = errors + 1;
    end

    // Phase 3: same sequence, invariant DROPPED -> must fail.
    g <= 1'b0;
    repeat (4) @(posedge clk);
    if (fail_fixed == 0) begin
      $display("FAIL: fixed-length throughout did NOT fire when the invariant");
      $display("      was dropped -- the check is inert");
      errors = errors + 1;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
    $finish;
  end

endmodule
