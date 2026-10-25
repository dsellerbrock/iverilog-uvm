module m; int x=5, r=0; initial begin case (x) 1: r=1; default: r=10; default: r=20; endcase $display("DD r=%0d", r); end endmodule
