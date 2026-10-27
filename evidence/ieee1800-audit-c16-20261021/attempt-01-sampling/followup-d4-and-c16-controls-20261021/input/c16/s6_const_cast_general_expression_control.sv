`timescale 1ns/1ns
module tb;
  int cnt=2;
  initial begin $display("S6 control const=%0d",const'(cnt)); #50 $finish; end
endmodule
