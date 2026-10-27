`timescale 1ns/1ns
interface bus_if(input logic clk, input logic [3:0] d);
endinterface
interface bound_mon_if(input logic clk, input logic [3:0] v);
  always @(posedge clk) $display("%m v=%h t=%0t", v, $time);
endinterface
bind bus_if bound_mon_if im(.clk(clk), .v(d));
module top;
  logic clk = 0;
  logic [3:0] d = 9;
  always #5 clk = ~clk;
  bus_if bus(.clk(clk), .d(d));
  initial begin #16 $finish; end
endmodule
