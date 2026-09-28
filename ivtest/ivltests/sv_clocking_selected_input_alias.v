`timescale 1ns/1ps
interface sampled_if(input logic clk);
  logic [3:0] raw;
  logic [1:0][1:0] rows;
  clocking cb @(posedge clk);
    input bit_one = raw[1];
    input pair = rows[1];
  endclocking
  clocking cb0 @(posedge clk);
    input #0 bit_one = raw[1];
    input #0 pair = rows[1];
  endclocking
endinterface

module sv_clocking_selected_input_alias;
  bit clk;
  sampled_if bus(clk);
  virtual sampled_if vif;
  initial begin
    vif = bus;
    bus.raw = 4'b1010;
    bus.rows = 4'b1010;
    #5 bus.raw = 4'b0101; bus.rows = 4'b0101; clk = 1;
    #1;
    if (bus.cb.bit_one !== 1'b1 || bus.cb.pair !== 2'b10)
      $fatal(1, "first physical sample bit=%b pair=%b", bus.cb.bit_one, bus.cb.pair);
    if (vif.cb.bit_one !== 1'b1 || vif.cb.pair !== 2'b10)
      $fatal(1, "first VIF sample bit=%b pair=%b", vif.cb.bit_one, vif.cb.pair);
    if (bus.cb0.bit_one !== 1'b0 || bus.cb0.pair !== 2'b01
        || vif.cb0.bit_one !== 1'b0 || vif.cb0.pair !== 2'b01)
      $fatal(1, "#0 selected input sample");
    clk = 0;
    #5 clk = 1;
    #1;
    if (bus.cb.bit_one !== 1'b0 || bus.cb.pair !== 2'b01)
      $fatal(1, "second physical sample bit=%b pair=%b", bus.cb.bit_one, bus.cb.pair);
    if (vif.cb.bit_one !== 1'b0 || vif.cb.pair !== 2'b01)
      $fatal(1, "second VIF sample bit=%b pair=%b", vif.cb.bit_one, vif.cb.pair);
    $display("PASS");
    $finish;
  end
endmodule
