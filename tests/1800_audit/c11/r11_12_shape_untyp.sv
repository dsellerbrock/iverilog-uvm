module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let u(untyped v) = v; initial $display("UT %0d", u(5)); endmodule
