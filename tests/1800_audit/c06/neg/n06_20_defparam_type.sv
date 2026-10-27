module s #(parameter type T = int)(); endmodule
module m; s u(); defparam u.T = shortint; endmodule
