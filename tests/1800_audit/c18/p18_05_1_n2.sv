class X; rand bit [3:0] x; constraint p; endclass
constraint X::p { x < 4; }
constraint X::p { x > 2; }
module m; initial begin X o; o = new; void'(o.randomize()); $display("RAN x=%0d", o.x); end endmodule
