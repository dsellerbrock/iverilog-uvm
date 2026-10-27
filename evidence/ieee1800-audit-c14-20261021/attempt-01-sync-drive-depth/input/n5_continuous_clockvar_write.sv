`timescale 1ns/1ps
interface bus_if(input logic clk);
  logic data = 0;
  clocking cb @(posedge clk);
    output data;
  endclocking
endinterface
module top;
  logic clk = 0;
  always #5 clk = ~clk;
  bus_if bus(clk);
  assign top.bus.cb.data = 1'b1;
endmodule
