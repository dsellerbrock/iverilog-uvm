`timescale 1ns/1ns
module tb;
  logic a = 1;
  bit clk;
  always #5 clk = ~clk;
  initial begin #12 a = 0; #6 a = 1; end
  initial #40 $finish;
  clocking cb_with_input @(posedge clk);
    input a;
  endclocking
  property p2;
    @(posedge clk) cb_with_input.a;
  endproperty
  assert property (p2) else $display("K2 FAIL %0t", $time);
endmodule
