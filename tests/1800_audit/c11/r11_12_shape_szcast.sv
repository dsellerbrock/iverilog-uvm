module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let m2(x,y) = 8'(x*y); initial $display("SZ %0d", m2(a,a)); endmodule
