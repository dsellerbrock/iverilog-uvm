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
    #8;
    vif.cb.data <= 8'h11;
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
    d.run();
    #8;
    $display("FINAL %0t %h", $time, bus.data);
    $finish;
  end
endmodule
