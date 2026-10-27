`timescale 1ns/1ps
interface bus_if(input logic clk);
  logic [7:0] data = 8'hA0;
  clocking cb @(posedge clk);
    output data;
  endclocking
endinterface
class driver;
  virtual interface bus_if vif;
  task run();
    @(vif.cb);
    vif.cb.data[3:0] <= 4'hF;
  endtask
endclass
module test;
  logic clk = 0;
  always #5 clk = ~clk;
  bus_if bus(clk);
  driver d;
  always @(bus.data) $display("DATA %0t %h", $time, bus.data);
  initial begin
    d = new();
    d.vif = bus;
    fork d.run(); join_none
    #6;
    $display("FINAL %0t %h", $time, bus.data);
    $finish;
  end
endmodule
