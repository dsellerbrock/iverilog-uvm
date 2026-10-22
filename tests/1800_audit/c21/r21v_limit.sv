module top; reg [7:0] cnt=0; always #1 cnt=cnt+1; initial begin $dumpfile("limit.vcd"); $dumpvars; $dumplimit(300); #200 $finish; end endmodule
