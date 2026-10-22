module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let c2(x,y) = {x,y}; initial $display("CC %0d", c2(a,a)); endmodule
