module top #(parameter p=1, q=2); wire a=1; initial #1 $display("NB %0d %0d", p, q); endmodule
