module m; reg [1:0] s=2'b11; initial begin $dumpfile("r1.vcd"); #10 $dumpvars(0,m); #10 $dumpoff; #5 s=2'b00; #5 $dumpon; #5 $finish; end endmodule
