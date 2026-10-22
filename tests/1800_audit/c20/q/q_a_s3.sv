module m; int a[3][][5];
initial begin  $display("Q a_s3=%0d exp 5", $size(a,3)); end endmodule
