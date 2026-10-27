module m; real r=1.5; bit [63:0] x; initial begin x = {>>{r}}; $display("RL x=%h", x); end endmodule
