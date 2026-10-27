module m; class X; rand bit [3:0] x; extern constraint p; endclass initial begin X o = new; void'(o.randomize()); end endmodule
