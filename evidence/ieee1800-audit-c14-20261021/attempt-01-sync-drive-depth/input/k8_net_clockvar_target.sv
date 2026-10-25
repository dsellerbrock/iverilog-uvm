`timescale 1ns/1ps
interface bus_if(input logic clk);
  wire w;
  clocking cb @(posedge clk);
    output w;
  endclocking
endinterface
class driver;
  virtual interface bus_if vif;
  task run();
    @(vif.cb);
    vif.cb.w <= 1'b1;
  endtask
endclass
module test;
  logic clk = 0;
  always #5 clk = ~clk;
  bus_if bus(clk);
  driver d;
  initial begin
    #1;
    $display("INITIAL %0t %b", $time, bus.w);
    d = new();
    d.vif = bus;
    d.run();
    #1;
    $display("DRIVEN %0t %b", $time, bus.w);
    $finish;
  end
endmodule
