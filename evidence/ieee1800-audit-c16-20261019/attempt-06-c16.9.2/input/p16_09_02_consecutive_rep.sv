`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic start_exact = 0, exact_a = 0, exact_tail = 0;
  logic start_range = 0, range_a = 0, range_tail = 0;
  int exact_hits = 0, range_hits = 0;
  always #5 clk = ~clk;

  cover property (@(posedge clk)
    $rose(start_exact) |-> (exact_a[*3] ##1 exact_tail)) exact_hits++;
  cover property (@(posedge clk)
    $rose(start_range) |-> (range_a[*1:3] ##1 range_tail)) range_hits++;

  initial begin
    @(negedge clk);
    start_exact = 1; exact_a = 1;
    start_range = 1; range_a = 1;
    @(negedge clk);
    start_exact = 0;
    start_range = 0;
    @(negedge clk);
    range_a = 0; range_tail = 1;
    @(negedge clk);
    exact_a = 0; exact_tail = 1; range_tail = 0;
    repeat (2) @(negedge clk);
    if (exact_hits != 1 || range_hits != 1)
      $fatal(1, "consecutive exact=%0d range=%0d", exact_hits, range_hits);
    $display("PASSED: consecutive exact and range repetition");
    $finish(0);
  end
endmodule
