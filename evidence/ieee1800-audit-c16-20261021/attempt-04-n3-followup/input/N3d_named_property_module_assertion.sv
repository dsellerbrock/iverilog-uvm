`timescale 1ns/1ns
module tb;
  bit clk;
  always #5 clk = ~clk;
  logic a = 1, b = 1, c = 1;
  initial begin #12 a = 0; #6 a = 1; end
  initial begin #17 b = 0; #6 b = 1; end
  initial #60 $finish;
  property q1;
    $rose(a) |-> ##[1:5] b;
  endproperty
  assert property (@(negedge clk) $fell(c) |=> q1)
    else $display("N3d FAIL %0t", $time);
endmodule
