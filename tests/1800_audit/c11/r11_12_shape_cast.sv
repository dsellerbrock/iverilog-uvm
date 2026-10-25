module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let c3(x) = int'(x); initial $display("CT %0d", c3(a)); endmodule
