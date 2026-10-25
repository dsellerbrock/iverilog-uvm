module m; event e1, e2; initial begin e2 = e1; $display("C %b", e2 == e1); end endmodule
