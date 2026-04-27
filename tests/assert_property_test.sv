// assert_property_test.sv — verify `assert property (...)` with the
//   `|->` and `|=>` implication operators parses and compiles. We do
//   NOT yet model the temporal semantics — the property is silently
//   dropped — but the source compiles and runs cleanly.

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
