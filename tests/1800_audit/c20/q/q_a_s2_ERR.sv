module m; int a[3][][5];
initial begin a[2]=new[4]; $display("Q a_s2_ERR=%0d exp error", $size(a,2)); end endmodule
