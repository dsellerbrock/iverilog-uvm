// M13 negative: bind port expression referencing a name that does
// not exist inside the target must fail elaboration loudly.
module dut(input logic clk); endmodule
module chk(input logic c); endmodule
bind dut chk c1(.c(no_such_signal));
module top; dut u0(.clk(1'b0)); initial $finish(0); endmodule
