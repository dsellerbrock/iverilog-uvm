`timescale 1ns/1ns
module bound_check(input logic clk, input logic [3:0] v);
  a_not_f: assert property (@(posedge clk) v != 4'hf)
    else $display("%m FAIL %0t", $time);
endmodule
module dut(input logic clk, input logic [3:0] d);
  logic [3:0] q;
  always @(posedge clk) q <= d;
endmodule
bind dut bound_check c(.clk(clk), .v(d));
module top;
  logic clk = 0;
  logic [3:0] d1 = 3, d2 = 5;
  always #5 clk = ~clk;
  dut u1(.clk(clk), .d(d1));
  dut u2(.clk(clk), .d(d2));
  initial begin #12 d1 = 4'hf; #18 $finish; end
endmodule
