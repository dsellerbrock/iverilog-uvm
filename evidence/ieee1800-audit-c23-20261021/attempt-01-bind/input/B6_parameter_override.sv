`timescale 1ns/1ns
module mon #(parameter int W = 1)(input logic clk, input logic [W-1:0] v);
  always @(posedge clk) $display("%m W=%0d v=%h t=%0t", W, v, $time);
endmodule
module dut(input logic clk, input logic [3:0] d);
  logic [3:0] q;
  always @(posedge clk) q <= d;
endmodule
bind dut mon #(.W(7)) m(.clk(clk), .v(d));
module top;
  logic clk = 0;
  logic [3:0] d1 = 3, d2 = 5;
  always #5 clk = ~clk;
  dut u1(.clk(clk), .d(d1));
  dut u2(.clk(clk), .d(d2));
  initial begin #12 d1 = 4'hf; #18 $finish; end
endmodule
