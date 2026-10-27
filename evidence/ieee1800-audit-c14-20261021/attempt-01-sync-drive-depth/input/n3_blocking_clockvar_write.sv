`timescale 1ns/1ps
interface bus_if(input logic clk);
  logic [7:0] data = 0;
  clocking cb @(posedge clk);
    output data;
  endclocking
endinterface
class driver;
  virtual interface bus_if vif;
  task run();
    vif.cb.data = 8'h01;
  endtask
endclass
module test;
  logic clk = 0;
  always #5 clk = ~clk;
  bus_if bus(clk);
  driver d;
  initial begin
    d = new();
    d.vif = bus;
    d.run();
  end
endmodule
