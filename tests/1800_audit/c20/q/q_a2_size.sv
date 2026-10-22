module m; int a[3][][5];
initial begin a[2]=new[4]; $display("Q a2_size=%0d exp 4", $size(a[2],1)); end endmodule
