`timescale 1ns/1ps
module test;
  logic clk = 0, start = 0, b = 0, c = 0;
  int cycles = 0;
  int pass_nonconsecutive = 0, fail_nonconsecutive = 0;
  int pass_goto = 0, fail_goto = 0;
  always #5 clk = ~clk;
  always @(posedge clk) cycles++;

  assert property (@(posedge clk) $rose(start) |-> b[=2] ##1 c)
    pass_nonconsecutive++;
    else fail_nonconsecutive++;
  assert property (@(posedge clk) $rose(start) |-> b[->2] ##1 c)
    pass_goto++;
    else fail_goto++;

  initial begin
    @(negedge clk); start = 1; b = 1;
    @(negedge clk); start = 0; b = 0;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0;
    @(negedge clk); b = 0;
    @(negedge clk); b = 0; c = 1;
    @(negedge clk); c = 0;
    repeat (2) @(negedge clk);
    if (fail_nonconsecutive != 0 ||
        pass_nonconsecutive + fail_nonconsecutive != cycles ||
        fail_goto != 1 || pass_goto + fail_goto != cycles)
      $fatal(1, "cycles=%0d nonconsecutive pass/fail=%0d/%0d goto pass/fail=%0d/%0d",
             cycles, pass_nonconsecutive, fail_nonconsecutive, pass_goto, fail_goto);
    $display("PASSED: nonconsecutive repetition extends through two false ticks");
    $finish(0);
  end
endmodule
