`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic data = 0;
  always #5 clk = ~clk;

  default clocking cb @(posedge clk);
    input data;
  endclocking

  initial begin
    @(cb);
    ##0;
    if ($time !== 5) begin
      $display("FAIL: post-event ##0 resumed at %0t; expected to continue at 5", $time);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
