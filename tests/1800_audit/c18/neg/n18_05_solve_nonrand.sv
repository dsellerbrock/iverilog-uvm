class C; int a; rand int b; constraint o { solve a before b; b == 1; } endclass
module t; C c = new; initial begin if (!c.randomize()) $fatal(1, "randomize failed"); $display("RESULT randomize returned 1"); end endmodule
