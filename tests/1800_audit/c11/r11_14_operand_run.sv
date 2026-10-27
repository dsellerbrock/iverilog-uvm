module m; int a=5, x; initial begin x = {>>{a}} + 1; $display("OP x=%0d", x); end endmodule
