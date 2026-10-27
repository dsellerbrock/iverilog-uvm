package pk; let f(a,b,c) = (a & b) || c; endpackage
module m; initial $display("ARGS %0d",pk::f(1,1,0)); endmodule
