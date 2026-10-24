module top; reg [3:0] a=1; sub m1(); initial begin $dumpfile("lv2.vcd"); $dumpvars(0,top.m1); #5 a=2; #5 $finish; end endmodule
module sub; reg b=0; endmodule
