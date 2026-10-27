`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic start_exact = 0, exact_a = 0, exact_tail = 0;
  logic start_range = 0, range_a = 0, range_tail = 0;
  int cycles = 0;
  int pass_exact = 0, fail_exact = 0;
  int pass_range = 0, fail_range = 0;
  always #5 clk = ~clk;
  always @(posedge clk) cycles++;

  assert property (@(posedge clk)
    $rose(start_exact) |-> exact_a[*3] ##1 exact_tail)
    pass_exact++;
    else fail_exact++;
  assert property (@(posedge clk)
    $rose(start_range) |-> range_a[*1:3] ##1 range_tail)
    pass_range++;
    else fail_range++;

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
    if (fail_exact != 0 || pass_exact + fail_exact != cycles ||
        fail_range != 0 || pass_range + fail_range != cycles)
      $fatal(1, "cycles=%0d exact pass/fail=%0d/%0d range pass/fail=%0d/%0d",
             cycles, pass_exact, fail_exact, pass_range, fail_range);
    $display("PASSED: consecutive exact and range repetition");
    $finish(0);
  end
endmodule
