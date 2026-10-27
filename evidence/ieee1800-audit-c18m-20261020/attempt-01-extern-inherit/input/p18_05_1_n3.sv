module m; class X; rand bit [3:0] x; constraint p; constraint p { x == 1; } endclass initial begin X o = new; void'(o.randomize()); end endmodule
