module s #(parameter type T = int)(); endmodule
module m; s #(.T(5)) u(); endmodule
