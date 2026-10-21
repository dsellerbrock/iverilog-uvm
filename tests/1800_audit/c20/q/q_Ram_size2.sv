module m; typedef logic [16:1] Word; Word Ram[0:9];
initial begin  $display("Q Ram_size2=%0d exp 16", $size(Ram,2)); end endmodule
