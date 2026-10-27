module m; logic [7:0] V;
initial begin  $display("Q unp_V=%0d exp 0", $unpacked_dimensions(V)); end endmodule
