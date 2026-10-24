`timescale 1ns/1ps
module test;
  reg clk = 0;
  always #5 clk = ~clk;

  reg [3:0] a = 4'ha;
  reg [3:0] b = 4'h5;

  clocking cb @(posedge clk);
    input inst = {a, b};
  endclocking

  initial begin
    @(cb);
    if (cb.inst !== 8'ha5) begin
      $display("FAIL: expected 8'ha5, got %h", cb.inst);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
