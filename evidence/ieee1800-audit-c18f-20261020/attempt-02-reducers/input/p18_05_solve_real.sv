class C; rand real a; rand int b; constraint o { solve a before b; a inside {[0.0:1.0]}; } endclass
module p; C c = new; initial begin if (!c.randomize() || c.a < 0.0 || c.a > 1.0) $fatal(1, "real solve-before failed"); $display("RESULT pass=1 fail=0"); end endmodule
