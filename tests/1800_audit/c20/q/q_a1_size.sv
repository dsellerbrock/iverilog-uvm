module m; int a[3][][5];
initial begin  $display("Q a1_size=%0d exp 0", $size(a[1],1)); end endmodule
