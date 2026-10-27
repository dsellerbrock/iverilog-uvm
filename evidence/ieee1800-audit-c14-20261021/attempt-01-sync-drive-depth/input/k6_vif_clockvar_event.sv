`timescale 1ns/1ps
interface bus_if(input logic clk);
  logic [7:0] rdata = 0;
  clocking cb @(posedge clk);
    default input #1step;
    input rdata;
  endclocking
endinterface
class sampler;
  virtual interface bus_if vif;
  task run();
    #6;
    @(vif.cb.rdata);
    $display("EVENT %0t %0d", $time, vif.cb.rdata);
  endtask
endclass
module test;
  logic clk = 0;
  always #5 clk = ~clk;
  bus_if bus(clk);
  always @(posedge clk) bus.rdata <= bus.rdata + 1'b1;
  sampler s;
  initial begin
    s = new();
    s.vif = bus;
    s.run();
    #1;
    $finish;
  end
endmodule
