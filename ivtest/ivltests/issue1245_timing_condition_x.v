`timescale 1ns/1ps
module dut(input clk, d, en, output reg nd = 0, output reg nn = 0);
  specify
    $setup(d, posedge clk &&& (en === 1'b1), 2, nd);
    $setup(d, posedge clk &&& (en == 1'b1), 2, nn);
  endspecify
endmodule
module issue1245_timing_condition_x;
  reg clk = 0, d = 0, en = 1'bx;
  wire nd, nn;
  dut u(clk, d, en, nd, nn);
  initial begin
    #10 d = 1;
    #1 clk = 1;
    #1 $display("det=%b nondet=%b", nd, nn);
    if (nd !== 1'b0 || nn !== 1'b1) $fatal(1, "timing condition X semantics");
    $finish;
  end
endmodule
