typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int nv=0, y=1, z=0;
initial begin v=tagged Valid(5); nv = v matches tagged Valid .n &&& n>7 ? n : -1; $display("h4 nv=%0d", nv); end endmodule
