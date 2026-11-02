module test;
  logic clk = 0, a = 0, b = 0;
  int failures = 0;
  always #5 clk = ~clk;

  property p_multi_atom;
    int x, y;
    @(posedge clk) (a, x = 1, y = x + 1) |-> ##1 (x == 1 && y == 2);
  endproperty

  property p_multi_sequence;
    int x, y;
    @(posedge clk) (a ##1 b, x = 3, y = x + 1) |-> ##1 (x == 3 && y == 4);
  endproperty

  assert property (p_multi_atom) else failures++;
  assert property (p_multi_sequence) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 0;
    repeat (3) @(negedge clk);
    if (failures != 0)
      $fatal(1, "multiple match-item assignment failures=%0d", failures);
    $display("PASSED");
    $finish(0);
  end
endmodule
