module m; initial begin #2 $fatal(1, "f1"); $display("AFTER1"); end endmodule
