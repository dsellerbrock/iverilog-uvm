module m; event e1, e2; int hits = 0; initial begin e2 = e1; fork begin @(e2); hits++; end begin #1; -> e1; end join $display("E hits=%0d", hits); end endmodule
