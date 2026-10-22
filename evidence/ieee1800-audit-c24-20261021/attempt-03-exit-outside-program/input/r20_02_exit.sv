program pg; initial begin #5 $display("PROG done"); end endprogram
module m; initial begin #1 $display("EX0"); $exit; end initial #20 $display("LATE"); endmodule
