`timescale 1ns/1ps
module test;
  reg clk = 0;
  always #5 clk = ~clk;

  reg [7:0] bus = 8'ha5;

  clocking cb @(posedge clk);
    input low = bus[3:0];
    input high = bus[7:4];
  endclocking

  initial begin
    @(cb);
    if (cb.low !== 4'h5 || cb.high !== 4'ha) begin
      $display("FAIL: expected low=5 high=a, got low=%h high=%h", cb.low, cb.high);
      $finish(1);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
