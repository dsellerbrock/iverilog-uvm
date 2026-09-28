`timescale 1ns/1ps
module tb;
  logic [3:0] x = 4'b0000;
  initial begin
    #1;
    x[1:0] <= 2'b01;
    x[3:2] <= 2'b10;
    #1;
    x <= 4'b1111;
    x <= 4'b0000;
    #1;
  end
endmodule
