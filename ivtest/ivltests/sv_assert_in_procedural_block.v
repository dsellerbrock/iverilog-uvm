// A concurrent assertion inside a procedural begin/end must actually run.
//
// P0 silent miscompile, found while implementing M9-10. A concurrent
// assertion synthesizes its own clocked always block plus the state
// variables that block needs, at the point the assertion is parsed. For
//
//     always @(posedge clk) begin
//       assert property (@(posedge clk) a |-> b) else fails++;
//     end
//
// that point has lexical_scope set to the enclosing begin/end PBlock.
// Nothing elaborates a PBlock's `behaviors' list -- only modules and
// generate blocks are walked -- and the seq_block rule deletes an unnamed
// block whose scope holds no declarations outright. So the assertion and
// its variables were dropped WITH NO DIAGNOSTIC: it registered itself,
// never evaluated, never failed, and the design looked clean. Exactly the
// failure mode a regression suite cannot notice, because a dropped
// assertion is indistinguishable from a passing one.
//
// The fix runs the lowering against the nearest enclosing non-block scope.
// This test drives an assertion that MUST fail and compares the count
// against the identical assertion written outside a block, so a dropped
// assertion shows up as a mismatch rather than as silence.
module main;

  reg clk = 0;
  reg a = 1;
  reg b = 0;      // a |-> b therefore fails on every posedge

  int bare_fails  = 0;   // control: assertion is the whole always body
  int block_fails = 0;   // the regression: assertion inside begin/end
  int deep_fails  = 0;   // nested one level further, under an inner @

  always @(posedge clk)
    assert property (@(posedge clk) a |-> b) else bare_fails++;

  always @(posedge clk) begin
    assert property (@(posedge clk) a |-> b) else block_fails++;
  end

  always @(posedge clk) begin
    if (1) begin
      assert property (@(posedge clk) a |-> b) else deep_fails++;
    end
  end

  initial begin
    #5 clk = 1;
    #5 clk = 0;
    #5 clk = 1;
    #5 clk = 0;
    #5;

    if (bare_fails == 0)
      $display("FAILED -- the control assertion never fired (%0d); the test itself is broken",
               bare_fails);
    else if (block_fails != bare_fails)
      $display("FAILED -- block=%0d bare=%0d; an assertion inside begin/end was dropped",
               block_fails, bare_fails);
    else if (deep_fails != bare_fails)
      $display("FAILED -- deep=%0d bare=%0d; an assertion nested two blocks down was dropped",
               deep_fails, bare_fails);
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
