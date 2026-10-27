`timescale 1ns/1ns
module tb;
  logic a = 1;
  bit clk;
  always #5 clk = ~clk;
  initial begin #12 a = 0; #6 a = 1; end
  initial #40 $finish;
  property p1;
    @(posedge clk) a;
  endproperty
  assert property (p1) else $display("K1 FAIL %0t", $time);
endmodule
