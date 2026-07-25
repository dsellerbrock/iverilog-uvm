// R2: a concurrent assertion is evaluated in the OBSERVED region
// (IEEE 1800-2017 4.4.2.4), after every nonblocking update of the time step
// has settled -- not in Active, interleaved with the design it is judging.
//
// M6B-4 fixed which VALUES an assertion samples (the Preponed ones) but left
// WHEN it runs alone, so the synthesized checker's `always @(clk)' competed
// with the design's own Active-region processes.
//
// The discriminator is an action that reads a signal updated by NBA at the
// same edge. Evaluated in Active, the action saw the pre-NBA value; in
// Observed it sees the settled one. Against the pre-fix compiler this
// printed `seen=0'.
//
// Sampled operands are deliberately unaffected and are checked here too:
// %load/preponed returns the value the signal held when the step began,
// whenever the read happens, so moving the read later must not change a
// single verdict. `sampled_ok' fails if it did.
module main;

  reg clk = 0;
  reg b = 0;               // assertion operand: always false, so it fails
  reg [7:0] v = 8'd0;      // updated by NBA at the same edge
  reg s = 0;               // sampled operand, blocking-written at the edge

  int seen = -1;
  int fails = 0;
  int sampled_ok = 0;

  always @(posedge clk) v <= v + 1;

  always @(posedge clk) assert property (@(posedge clk) b) else seen = v;

  // s is 0 in the Preponed region of the edge and 1 by the Active region.
  // The assertion must still see 0 and fail, exactly as before this change.
  always @(posedge clk) assert property (@(posedge clk) s) else fails++;

  initial begin
    #5 s = 1; clk = 1;     // blocking write to s in the clock's own slot
    #5 clk = 0; s = 0;
    #5;

    if (seen == -1)
      $display("FAILED -- the action never ran (%0d); the test itself is broken", seen);
    else if (seen != 1)
      $display("FAILED -- the action saw v=%0d, expected 1; the assertion is still evaluated before the nonblocking updates settle",
               seen);
    else if (fails != 1)
      $display("FAILED -- the sampled operand produced %0d failures, expected 1; moving evaluation to Observed changed what it sampled",
               fails);
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
