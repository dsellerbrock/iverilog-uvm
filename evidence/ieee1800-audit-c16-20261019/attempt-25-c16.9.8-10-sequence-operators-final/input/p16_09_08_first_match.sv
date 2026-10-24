`timescale 1ns/1ps
module test;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  // A single evaluation attempt must recognize the first_match sequence.
  cover property (@(posedge clk) first_match(a ##[1:2] b));

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);

    if (_ivl_sva0_cnt0 != 1)
      $fatal(1, "§16.9.8 expected one first_match cover, got %0d",
             _ivl_sva0_cnt0);
    $display("PASSED: §16.9.8 first_match recognized a sequence match");
    $finish(0);
  end
endmodule
