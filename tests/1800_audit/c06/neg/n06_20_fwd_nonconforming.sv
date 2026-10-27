module s #(parameter type enum E = enum {A, B}); endmodule
module m; s #(.E(int)) u(); endmodule
