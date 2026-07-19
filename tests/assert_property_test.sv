// assert_property_test.sv — verify `assert property (...)` with the
//   `|->` and `|=>` implication operators compiles and runs cleanly
//   on always-true properties. Since M9 these assertions synthesize
//   real token-pipeline checkers with correct overlap and next-cycle
//   semantics (they are no longer parse-and-drop); the full engine is
//   exercised by m9_sva_engine_test.sv and the other m9*_test.sv
//   suites, including failing stimulus.

module top;
  logic clk = 0;
  logic a = 1, b = 1;
  always #5 clk = ~clk;
  initial begin
    #50 $display("PASS assert property compiled and ran");
    $finish;
  end
  // Overlapping implication
  assert property (@(posedge clk) a |-> b);
  // Non-overlapping implication
  assert property (@(posedge clk) a |=> b);
endmodule
