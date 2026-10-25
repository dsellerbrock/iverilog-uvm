class X; rand bit [3:0] x; pure constraint t; endclass
module m; initial begin X o; o = new; void'(o.randomize()); $display("RAN x=%0d", o.x); end endmodule
