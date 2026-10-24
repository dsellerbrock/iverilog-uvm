virtual class V; rand bit [3:0] w; pure constraint t; endclass
class X extends V; endclass
module m; initial begin X o; o = new; void'(o.randomize()); $display("RAN w=%0d", o.w); end endmodule
