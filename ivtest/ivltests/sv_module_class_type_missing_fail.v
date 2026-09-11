class holder; endclass
module test; (* probe = (1+2) *) holder::absent [3:0] x[2] = '{1,2}, y[1:0]; endmodule
