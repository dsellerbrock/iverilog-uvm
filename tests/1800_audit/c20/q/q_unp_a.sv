module m; int a[3][][5];
initial begin  $display("Q unp_a=%0d exp 3", $unpacked_dimensions(a)); end endmodule
