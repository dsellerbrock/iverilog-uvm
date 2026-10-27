`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  wire [3:0] nibble;
  default clocking pe @(posedge clk); output nibble; endclocking
  always @(nibble) $display("%0t nibble=%h", $time, nibble);
  initial begin ##2 pe.nibble<=4'b0101; pe.nibble<=4'b0011; end
  initial #50 $finish;
endmodule
