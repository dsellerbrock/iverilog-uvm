module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let t2(x) = x ? 1 : 2; initial $display("CD %0d", t2(1'b1)); endmodule
