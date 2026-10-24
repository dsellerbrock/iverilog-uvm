module test;
  logic clk = 0, a = 0;
  int failures = 0;
  always #5 clk = ~clk;

  property p_init;
    int cnt = 0;
    @(posedge clk) (a, cnt = cnt + 1) |-> ##1 (cnt == 1);
  endproperty
  assert property (p_init) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0;
    repeat (3) @(negedge clk);
    if (failures != 0) $fatal(1, "initialized local variable failures=%0d", failures);
    $display("PASSED: §16.10 local declaration initializer");
    $finish(0);
  end
endmodule
