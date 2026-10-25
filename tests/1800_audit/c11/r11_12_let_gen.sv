module m; generate if (1) begin: g let f(x)=x+1; initial $display("G %0d", f(1)); end endgenerate endmodule
