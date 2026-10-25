`timescale 1ns/1ps
interface bus_if(input logic clk);
  logic [7:0] data = 0;
  clocking cb @(posedge clk);
    output data;
  endclocking
endinterface
module top;
  logic clk = 0;
  always #5 clk = ~clk;
  bus_if bus(clk);
  always @(bus.data) $display("DATA %0t %h", $time, bus.data);
  initial begin
    @(top.bus.cb);
    top.bus.cb.data <= ##2 8'h3C;
    $display("AFTER %0t", $time);
    #26;
    $display("FINAL %0t %h", $time, bus.data);
    $finish;
  end
endmodule
