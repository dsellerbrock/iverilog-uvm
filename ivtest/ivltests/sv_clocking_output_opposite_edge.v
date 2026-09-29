`timescale 1ns/1ps

interface clocking_output_edge_if(input logic clk);
  logic falling = 0;
  logic rising = 0;
  logic delayed = 0;
  clocking cb @(posedge clk);
    default output negedge;
    output falling;
    output posedge rising;
    output negedge #1 delayed;
  endclocking
endinterface

module sv_clocking_output_opposite_edge;
  logic clk = 0;
  always #5 clk = ~clk;
  clocking_output_edge_if bus(clk);
  virtual clocking_output_edge_if vif;

  initial begin
    vif = bus;
    #1;
    vif.cb.falling <= 1;
    vif.cb.rising <= 1;
    vif.cb.delayed <= 1;
    #5;
    if (bus.rising !== 1 || bus.falling !== 0 || bus.delayed !== 0)
      $fatal(1, "wrong outputs after first posedge at %0t", $time);
    #3;
    if (bus.falling !== 0 || bus.delayed !== 0)
      $fatal(1, "opposite-edge output drove early at %0t", $time);
    #2;
    if (bus.falling !== 1)
      $fatal(1, "opposite-edge output missed negedge at %0t", $time);
    #1;
    if (bus.delayed !== 1)
      $fatal(1, "opposite-edge delayed output missed skew at %0t", $time);
    vif.cb.falling <= 0;
    vif.cb.delayed <= 0;
    #6;
    if (bus.falling !== 1 || bus.delayed !== 1)
      $fatal(1, "next-cycle output drove before negedge at %0t", $time);
    #3;
    if (bus.falling !== 0)
      $fatal(1, "next-cycle output missed negedge at %0t", $time);
    #1;
    if (bus.delayed !== 0)
      $fatal(1, "next-cycle delayed output missed skew at %0t", $time);
    $display("PASSED");
    $finish;
  end
endmodule
