module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let m3(x,y) = $bits(x)+$bits(y); initial $display("BI %0d", m3(a,a)); endmodule
