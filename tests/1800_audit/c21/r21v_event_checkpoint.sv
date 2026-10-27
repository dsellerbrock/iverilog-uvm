`timescale 1ns/1ns
module m; event ev; initial begin $dumpfile("r3.vcd"); $dumpvars(0,m); #5 ->ev; #5 $dumpoff; #5 $dumpon; #5 $dumpall; #5 $finish; end endmodule
