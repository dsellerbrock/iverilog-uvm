`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic data = 0;
  always #5 clk = ~clk;

  default clocking cb @(posedge clk);
    input data;
  endclocking

  int n = 2;

  initial begin
    #4;
    ##1;
    if ($time != 5) begin
      $display("FAIL: ##1 resumed at %0t, expected 5", $time);
      $finish(1);
    end
    ##3;
    if ($time != 35) begin
      $display("FAIL: ##3 resumed at %0t, expected 35", $time);
      $finish(1);
    end
    ##n;
    if ($time != 55) begin
      $display("FAIL: ##n resumed at %0t, expected 55", $time);
      $finish(1);
    end
    ##(n + 1);
    if ($time != 85) begin
      $display("FAIL: ##(n+1) resumed at %0t, expected 85", $time);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
