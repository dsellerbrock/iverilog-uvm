typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int hit=0, y=1, z=0;
initial begin v=tagged Valid(5); if (v matches tagged Valid .n &&& (n==5)) hit=20; else hit=21; $display("g5 hit=%0d", hit); end endmodule
