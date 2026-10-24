module m; initial begin $display("S"); $display(w); $display("E"); end generate if (1) begin: g assign w = 1; end endgenerate endmodule
