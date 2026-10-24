typedef union tagged {void Invalid; int Valid;} V;
module m; V v; int hit; initial begin v=tagged Valid(5); case (v) matches tagged Valid .n: hit=n; default: hit=0; endcase $display("MN hit=%0d",hit); end endmodule
