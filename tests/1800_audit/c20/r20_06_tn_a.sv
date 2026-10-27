typedef bit node; node [2:0] X; int signed Y;
module m; initial begin $display("T1 [%s]", $typename(X)); $display("T2 [%s]", $typename(Y)); end endmodule
