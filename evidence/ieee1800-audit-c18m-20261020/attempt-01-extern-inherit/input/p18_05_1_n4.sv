module m; class X; rand bit [3:0] x; pure constraint t; endclass initial begin X o = new; void'(o.randomize()); end endmodule
