// M13 negative: binding a module into itself recurses forever and
// must be rejected at compile time.
module dut(input logic clk); endmodule
bind dut dut self_i(.clk(clk));
module top; dut u(.clk(1'b0)); initial $finish(0); endmodule
