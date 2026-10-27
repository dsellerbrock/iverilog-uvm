typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int hit=0, y=1, z=0;
initial begin v=tagged Valid(5); if (y &&& z) hit=1; else hit=2; $display("g3 hit=%0d", hit); end endmodule
