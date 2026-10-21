class C; rand int a, b; constraint o { solve a before b; solve b before a; a inside {[0:10]}; b inside {[0:10]}; } endclass
module t; C c = new; initial begin if (!c.randomize()) $fatal(1, "randomize failed"); $display("RESULT randomize returned 1"); end endmodule
