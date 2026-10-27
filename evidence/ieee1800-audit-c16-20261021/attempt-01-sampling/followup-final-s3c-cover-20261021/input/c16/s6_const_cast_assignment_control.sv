`timescale 1ns/1ns
module tb;
  int cnt=2;
  int cv=0;
  initial begin cv=const'(cnt); $display("S6 control const=%0d",cv); #50 $finish; end
endmodule
