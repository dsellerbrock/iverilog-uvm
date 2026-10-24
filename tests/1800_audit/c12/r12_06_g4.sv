typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int hit=0, y=1, z=0;
initial begin v=tagged Valid(5); hit = (v matches tagged Valid .n &&& n>3) ? n : -1; $display("g4 hit=%0d", hit); end endmodule
