`timescale 1ns/1ps
module test;
  logic clk = 0, start = 0, b = 0, c = 0;
  int hits = 0;
  always #5 clk = ~clk;

  cover property (@(posedge clk) $rose(start) |-> b[->2] ##1 c) hits++;

  initial begin
    @(negedge clk); start = 1; b = 1;
    @(negedge clk); start = 0; b = 0;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0;
    @(negedge clk); c = 1;
    @(negedge clk); c = 0;
    repeat (2) @(negedge clk);
    if (hits != 1)
      $fatal(1, "goto repetition hits=%0d", hits);
    $display("PASSED: goto repetition ends at second b");
    $finish(0);
  end
endmodule
