`timescale 1ns/1ps
module top;
  logic a = 0, b = 1;
  wire w1, w5;
  assign #(2,4) w1 = a & b;
  wire #5 w4 = b;
  assign w5 = a;
  initial begin #10 $probe_delays; end
endmodule
