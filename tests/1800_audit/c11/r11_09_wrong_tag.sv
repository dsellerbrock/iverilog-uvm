module m; typedef union tagged {void Invalid; int Valid;} V; V v; int x=7; initial begin v = tagged Invalid; x = v.Valid; $display("TAGRD x=%0d", x); end endmodule
