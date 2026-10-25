`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic data = 0;
  always #5 clk = ~clk;

  clocking cb @(posedge clk);
    input data;
  endclocking

  initial begin
    #1;
    @(cb);
    if ($time != 5) begin
      $display("FAIL: first clocking event at %0t, expected 5", $time);
      $finish(1);
    end
    @(cb);
    if ($time != 15) begin
      $display("FAIL: second clocking event at %0t, expected 15", $time);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
