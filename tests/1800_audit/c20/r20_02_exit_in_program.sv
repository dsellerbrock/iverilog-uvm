program pg; initial begin #1 $exit; end initial #5 $display("PROG2 done"); endprogram
module m; initial #20 $display("LATE"); endmodule
