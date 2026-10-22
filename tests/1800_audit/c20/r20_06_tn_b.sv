package A; enum {A,B,C=99} X; endpackage : A
module m; initial $display("T3 [%s]", $typename(A::X)); endmodule
