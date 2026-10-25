`timescale 1ns/1ns
module m; event ev; reg a=0; initial begin $dumpfile("r4.vcd"); $dumpvars(0,m); #5 a=1; #5 $finish; end endmodule
