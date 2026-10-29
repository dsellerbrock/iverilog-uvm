// IEEE 1800-2017/2023 16.9.8 and 16.11: calls and assignments retain list
// order, and call arguments see preceding local assignments.
module sv_assert_first_match_mixed_items;
  logic clk = 0, a = 0, b = 0;
  int failures = 0;
  always #5 clk = ~clk;

  sequence s;
    a ##1 b;
  endsequence

  property p;
    int x, y;
    @(posedge clk) first_match(s, $display("call-before"), x = 1,
                               $display("x=%0d", x), y = x + 1,
                               $display("y=%0d", y));
  endproperty
  assert property (p) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);

    if (failures != 0)
      $fatal(1, "first_match mixed-item failures=%0d", failures);
    $display("PASSED: mixed first_match items preserve source order");
    $finish(0);
  end
endmodule
