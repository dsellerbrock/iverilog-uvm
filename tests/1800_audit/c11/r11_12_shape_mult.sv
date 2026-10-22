module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let mult(x,y) = ($bits(x)+$bits(y))'(x*y); initial $display("M %0d", mult(a,a)); endmodule
