module test;
  logic clk = 0, a = 0;
  int failures = 0;
  always #5 clk = ~clk;

  property p_inc;
    int count;
    @(posedge clk) (a, count = 0) ##1 (1'b1, count++) |-> ##1 (count == 1);
  endproperty

  assert property (p_inc) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0;
    repeat (3) @(negedge clk);
    if (failures != 0) $fatal(1, "§16.10 increment match item failures=%0d", failures);
    $display("PASSED: §16.10 increment expression in match item");
    $finish(0);
  end
endmodule
