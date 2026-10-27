typedef union tagged {void Invalid; int Valid;} VInt; module m; VInt v; int hit=0, x=5, y=1;
initial begin v=tagged Valid(5); case (v) matches tagged Valid .n &&& n>3: hit=2; default: hit=3; endcase $display("f2 hit=%0d", hit); end endmodule
