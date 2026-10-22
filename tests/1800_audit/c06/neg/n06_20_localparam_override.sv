module s #(localparam L = 1)(); endmodule
module m; s #(.L(2)) u(); endmodule
