module m; logic [3:0] a=4'hF; logic [3:0] w=4'h8; let sq(int v) = v*v; initial $display("TI %0d", sq(-3)); endmodule
