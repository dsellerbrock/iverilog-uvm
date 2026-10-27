module test;
  logic clk = 0, a = 0;
  int failures = 0;
  always #5 clk = ~clk;

  property p_multi;
    int x, y;
    @(posedge clk) (a, x = 1, y = 2) |-> ##1 (x == 1 && y == 2);
  endproperty
  assert property (p_multi) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0;
    repeat (3) @(negedge clk);
    if (failures != 0) $fatal(1, "multiple match-item assignment failures=%0d", failures);
    $display("PASSED: §16.10 multiple assignments in match item");
    $finish(0);
  end
endmodule
