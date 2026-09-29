`timescale 1ns/1ps
interface array_if(input logic clk);
  logic [7:0] data[1:2];
  clocking cb @(posedge clk);
    input data;
  endclocking
endinterface

module sv_clocking_fixed_array_input;
  logic clk = 0;
  logic [7:0] sampled0;
  logic [7:0] sampled1;
  always #5 clk = ~clk;
  array_if bus(clk);
  virtual array_if vif;

  initial begin
    vif = bus;
    bus.data[1] = 8'h11;
    bus.data[2] = 8'h22;
    #5;
    bus.data[1] = 8'h33;
    bus.data[2] = 8'h44;
    #1;
    sampled0 = vif.cb.data[1];
    sampled1 = vif.cb.data[2];
    if (sampled0 !== 8'h11 || sampled1 !== 8'h22)
      $fatal(1, "clocking array input aliased live data at %0t", $time);
    #5;
    bus.data[1] = 8'h55;
    bus.data[2] = 8'h66;
    #4;
    bus.data[1] = 8'h77;
    bus.data[2] = 8'h88;
    #1;
    sampled0 = vif.cb.data[1];
    sampled1 = vif.cb.data[2];
    if (sampled0 !== 8'h55 || sampled1 !== 8'h66)
      $fatal(1, "clocking array input missed prior value at %0t", $time);
    $display("PASSED");
    $finish;
  end
endmodule
