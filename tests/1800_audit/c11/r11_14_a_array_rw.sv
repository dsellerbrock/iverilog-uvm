module m; logic [10:0] up[3:0]; initial begin up[3]=1; up[2]=2; up[1]=3; up[0]=4; $display("A %0d %0d %0d %0d", up[3], up[2], up[1], up[0]); end endmodule
