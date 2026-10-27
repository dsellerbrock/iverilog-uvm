module t; event a, b, c; int r = 0; initial begin wait_order(a, b, c) r = 1; else r = -1; $display("E7 %0d", r); end initial begin #1 -> a; #1 -> b; #1 -> c; end endmodule
