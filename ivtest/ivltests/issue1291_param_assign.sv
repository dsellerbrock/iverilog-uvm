module child #(parameter integer P=4)(); endmodule
module top; child #(.P(8)) u(); endmodule
