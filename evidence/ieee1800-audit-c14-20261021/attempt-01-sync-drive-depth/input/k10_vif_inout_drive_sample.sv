`timescale 1ns/1ps
interface bus_if(input logic clk);
  logic [7:0] x = 0;
  clocking cb @(posedge clk);
    default input #1step output #0;
    inout x;
  endclocking
endinterface
class driver;
  virtual interface bus_if vif;
  task run();
    #6;
    vif.cb.x <= 8'h77;
    #1;
    $display("EARLY %0t cb=%h signal=%h", $time, vif.cb.x, vif.x);
    #9;
    $display("LATE %0t signal=%h", $time, vif.x);
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
    #1;
    $finish;
  end
endmodule
