package A; typedef bit [9:1'b1] word; endpackage : A
module m; A::word W; initial $display("T4 [%s]", $typename(W)); endmodule
