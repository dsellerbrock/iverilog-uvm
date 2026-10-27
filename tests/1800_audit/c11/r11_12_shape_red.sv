module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let r1(x) = |x; initial $display("RD %0d", r1(w)); endmodule
