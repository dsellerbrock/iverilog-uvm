`timescale 1ns/1ps
module test;
  logic clk = 0, start = 0, b = 0, c = 0;
  int cycles = 0, pass_n = 0, fail_n = 0;
  always #5 clk = ~clk;
  always @(posedge clk) cycles++;

  assert property (@(posedge clk) $rose(start) |-> b[->2] ##1 c)
    pass_n++;
    else fail_n++;

  initial begin
    @(negedge clk); start = 1; b = 1;
    @(negedge clk); start = 0; b = 0;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0; c = 1;
    @(negedge clk); c = 0;
    repeat (2) @(negedge clk);
    if (fail_n != 0 || pass_n + fail_n != cycles)
      $fatal(1, "cycles=%0d goto pass/fail=%0d/%0d", cycles, pass_n, fail_n);
    $display("PASSED: goto repetition ends at second b");
    $finish(0);
  end
endmodule
