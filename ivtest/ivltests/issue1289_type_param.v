module child #(parameter type T=logic)(); endmodule
module top; child #(.T(bit)) u(); endmodule
