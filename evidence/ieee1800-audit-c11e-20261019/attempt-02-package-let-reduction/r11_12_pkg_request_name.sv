package pk; let f(request, valid, override) = |(request & valid) || override; endpackage
module m; initial $display("NAMED %0d",pk::f(1,1,0)); endmodule
