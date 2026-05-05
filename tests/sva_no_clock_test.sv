// G05 (Phase 68): assert property without explicit @(posedge clk) should
// compile and run cleanly.  The assertion is silently skipped (no clocking
// event → cannot synthesize an always block).
module top;
  logic clk = 0, a = 1, b = 1;
  always #5 clk = ~clk;

  // No explicit clocking: assertion is skipped; no "always without delay"
  // elaboration error.
  assert property (a |-> b) else $error("FAIL a|->b");
  assert property (a) else $error("FAIL a");

  initial begin
    #50;
    $display("PASS: G05 no-clock assertions skipped cleanly");
    $finish;
  end
endmodule
