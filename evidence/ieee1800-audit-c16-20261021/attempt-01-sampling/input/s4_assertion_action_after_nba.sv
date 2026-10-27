`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  logic x=0; always @(posedge clk) x<=1;
  assert property (@(posedge clk) 1'b0) else begin $display("S4 x=%0d",x); $finish; end
  initial #50 $finish;
endmodule
