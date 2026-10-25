module m; class X; rand bit [3:0] x; constraint p; endclass constraint X::p { x < 4; } constraint X::p { x > 2; } initial begin X o = new; void'(o.randomize()); end endmodule
