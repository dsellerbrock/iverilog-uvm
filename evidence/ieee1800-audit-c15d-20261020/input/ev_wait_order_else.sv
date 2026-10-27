module t; event a, b; int r = 0; initial begin wait_order(a, b) r = -1; else r = 1; $display("E8 %0d", r); end initial begin #1 -> b; #1 -> a; end endmodule
