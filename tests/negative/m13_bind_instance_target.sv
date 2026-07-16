// M13 negative: bind to a specific hierarchical instance is a
// recorded corner — must get a loud sorry, never a silent drop.
module dut(input logic clk); endmodule
module chk(input logic c); endmodule
module top; dut u0(.clk(1'b0)); initial $finish(0); endmodule
bind top.u0 chk c1(.c(clk));
