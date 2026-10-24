module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let tl(logic [3:0] v) = v+1; initial $display("TR %0d", tl(8'h1F)); endmodule
