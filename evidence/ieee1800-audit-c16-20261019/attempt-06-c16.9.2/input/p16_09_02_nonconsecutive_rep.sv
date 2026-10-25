`timescale 1ns/1ps
module test;
  logic clk = 0, start = 0, b = 0, c = 0;
  int goto_hits = 0, nonconsecutive_hits = 0;
  always #5 clk = ~clk;

  cover property (@(posedge clk) $rose(start) |-> b[->2] ##1 c) goto_hits++;
  cover property (@(posedge clk) $rose(start) |-> b[=2] ##1 c)
    nonconsecutive_hits++;

  initial begin
    @(negedge clk); start = 1; b = 1;
    @(negedge clk); start = 0; b = 0;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0;
    @(negedge clk); c = 1;
    @(negedge clk); c = 0;
    repeat (2) @(negedge clk);
    if (goto_hits != 0 || nonconsecutive_hits != 1)
      $fatal(1, "goto=%0d nonconsecutive=%0d", goto_hits,
             nonconsecutive_hits);
    $display("PASSED: nonconsecutive repetition extends over a false tick");
    $finish(0);
  end
endmodule
