`timescale 1ns/1ns
module tb;
  bit clk;
  always #5 clk = ~clk;
  logic b = 1;
  initial begin #17 b = 0; #6 b = 1; end
  initial #80 $finish;
  property q5;
    @(negedge clk) b[*3] |=> !b;
  endproperty
  always @(negedge clk)
    assert property (q5) else $display("N3b FAIL %0t", $time);
endmodule
