class X; rand bit [3:0] x; constraint p; constraint p { x == 1; } endclass
module m; initial begin X o; o = new; void'(o.randomize()); $display("RAN x=%0d", o.x); end endmodule
