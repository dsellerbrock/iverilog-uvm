module m; typedef logic [16:1] Word;
initial begin  $display("Q Word_left=%0d exp 16", $left(Word)); end endmodule
