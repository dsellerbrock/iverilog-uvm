module m; typedef logic [16:1] Word; Word Ram[0:9];
initial begin  $display("Q Ram_size=%0d exp 10", $size(Ram)); end endmodule
