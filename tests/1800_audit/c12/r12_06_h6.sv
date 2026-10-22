typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int nv=0, y=1, z=0;
initial begin v=tagged Valid(5); nv = y &&& z ? 1 : 2; $display("h6 nv=%0d", nv); end endmodule
