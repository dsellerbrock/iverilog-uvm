virtual class V; rand bit [3:0] w; pure constraint t; constraint t { w == 1; } endclass
class X extends V; constraint t { w == 2; } endclass
module m; initial begin X o; o = new; void'(o.randomize()); $display("RAN w=%0d", o.w); end endmodule
