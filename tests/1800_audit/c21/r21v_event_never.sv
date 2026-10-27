module m; event ev; reg a=0; initial begin $dumpfile("r2.vcd"); #5 $dumpvars(0,m); #5 $dumpall; #5 a=1; #5 $finish; end endmodule
