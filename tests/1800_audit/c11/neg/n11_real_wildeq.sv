module m; real r = 5.5, q; int i; initial begin i = (r ==? 5.5); $display("OUT q=%f i=%0d r=%f", q, i, r); end endmodule
