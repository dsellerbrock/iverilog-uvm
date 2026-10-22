module top; reg [3:0] a=1; sub m1(); initial begin $dumpfile("lv3.vcd"); $dumpvars(2,top); #5 $finish; end endmodule
module sub; reg b=0; sub2 m2(); endmodule
module sub2; reg c=0; endmodule
