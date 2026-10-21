typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int hit=0, x=5, y=1;
initial begin v=tagged Valid(5); if (v matches tagged Valid .n &&& n==5) hit=20; else hit=21; $display("f7 hit=%0d", hit); end endmodule
