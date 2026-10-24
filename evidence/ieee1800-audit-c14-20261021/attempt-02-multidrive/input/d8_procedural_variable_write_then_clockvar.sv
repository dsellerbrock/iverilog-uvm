`timescale 1ns/1ns
module tb;
  bit clk=0; always #5 clk=~clk;
  logic [7:0] d=0;
  clocking cb @(posedge clk); output d; endclocking
  always @(d) $display("%0t d=%h", $time, d);
  initial begin #7 d=8'h55; #9 $display("%0t check=%h", $time, d); @(cb) cb.d<=8'haa; end
  initial #50 $finish;
endmodule
