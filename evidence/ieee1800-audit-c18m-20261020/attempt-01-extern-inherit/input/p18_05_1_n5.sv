module m; virtual class V; rand bit [3:0] w; pure constraint t; endclass class X extends V; endclass initial begin X o = new; void'(o.randomize()); end endmodule
