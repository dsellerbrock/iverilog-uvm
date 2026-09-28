`timescale 1ns/1ps
module tb;
  logic clk = 0;
  logic [3:0] a = 4'b0001;
  logic [3:0] b = 4'b1001;
  logic [3:0] x = 4'b0000;

  always_ff @(posedge clk) begin
    x <= a;
    x <= b;
  end

  initial begin
    #1 clk = 1;
    #1 clk = 0;
    a = 4'b1111;
    b = 4'b0000;
    #1 clk = 1;
    #1;
  end
endmodule
