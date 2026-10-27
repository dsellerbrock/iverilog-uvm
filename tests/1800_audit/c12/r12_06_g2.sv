typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int hit=0, y=1, z=0;
initial begin v=tagged Valid(5); if (y &&& (y>0)) hit=1; else hit=2; $display("g2 hit=%0d", hit); end endmodule
