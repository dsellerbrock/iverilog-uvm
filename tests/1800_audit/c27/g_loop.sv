module top; genvar i;
 for (i=0;i<3;i=i+1) begin : b localparam L = i*2; wire [3:0] w = i; initial #1 $display("G1 %0d %0d %0d", i, L, w); end
 initial #2 $display("G1B %0d %0d", top.b[2].L, top.b[1].w);
endmodule
