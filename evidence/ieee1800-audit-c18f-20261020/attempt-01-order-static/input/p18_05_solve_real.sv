class C; rand real a; rand int b; constraint o { solve a before b; } endclass
module p; C c = new; initial begin if (!c.randomize()) $fatal(1, "randomize failed"); $display("RESULT pass=1 fail=0"); end endmodule
