`timescale 1ns/1ps
interface clocking_unpacked_net_output_if(input logic clk);
  uwire [7:0] raw [0:1];
  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_unpacked_net_output_fail;
  logic clk = 0;
  always #5 clk = ~clk;
  clocking_unpacked_net_output_if bus(clk);
  initial begin
    #1;
    if (bus.raw[0] !== 8'hzz || bus.raw[1] !== 8'hzz)
      $fatal(1, "unpacked uwire clocking drivers did not start at Z");
    bus.cb.raw[0] <= 8'h12;
    bus.cb.raw[1] <= 8'h34;
    @(posedge clk);
    #1;
    if (bus.raw[0] !== 8'h12 || bus.raw[1] !== 8'h34)
      $fatal(1, "unpacked uwire clocking drivers failed: %h %h",
             bus.raw[0], bus.raw[1]);
    $display("PASSED");
    $finish;
  end
endmodule
