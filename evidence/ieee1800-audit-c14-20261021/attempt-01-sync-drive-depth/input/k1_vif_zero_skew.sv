`timescale 1ns/1ps
interface bus_if(input logic clk);
  logic [7:0] data = 0;
  logic [7:0] rdata = 0;
  wire w;
  clocking cb @(posedge clk);
    default input #1step output #0;
    output data, w;
    input rdata;
  endclocking
endinterface
class driver;
  virtual interface bus_if vif;
  task run();
    @(vif.cb);
    vif.cb.data <= 8'hA5;
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
