`timescale 1ns/1ps
interface array_if(input logic clk);
  logic [7:0] data[1:2];
  clocking cb @(posedge clk);
    output data;
  endclocking
endinterface

module sv_clocking_fixed_array_output;
  logic clk = 0;
  always #5 clk = ~clk;
  array_if bus(clk);
  virtual array_if vif;

  initial begin
    vif = bus;
    bus.data[1] = 8'h11;
    bus.data[2] = 8'h22;
    #1;
    bus.cb.data[1] <= 8'h33;
    vif.cb.data[2] <= 8'h44;
    #3;
    if (bus.data[1] !== 8'h11 || bus.data[2] !== 8'h22)
      $fatal(1, "clocking array output drove before event at %0t", $time);
    #2;
    if (bus.data[1] !== 8'h33 || bus.data[2] !== 8'h44)
      $fatal(1, "clocking array output missed event at %0t", $time);
    #1;
    vif.cb.data[2] <= 8'h66;
    #7;
    if (bus.data[1] !== 8'h33 || bus.data[2] !== 8'h44)
      $fatal(1, "clocking array output drove before next event at %0t", $time);
    #2;
    if (bus.data[1] !== 8'h33 || bus.data[2] !== 8'h66)
      $fatal(1, "clocking array output missed next event at %0t", $time);
    $display("PASSED");
    $finish;
  end
endmodule
