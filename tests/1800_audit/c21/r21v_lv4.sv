module top; reg [3:0] a=1; sub m1(); initial begin $dumpfile("lv4.vcd"); $dumpvars(0,top.m1.b); #5 $finish; end endmodule
module sub; reg b=0; endmodule
