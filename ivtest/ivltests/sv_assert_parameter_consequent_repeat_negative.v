module invalid_checker #(parameter integer W = 3)(input logic clk, start, ready);
  a: assert property (@(posedge clk) start |=> !ready[*W] ##1 ready);
endmodule
module sv_assert_parameter_consequent_repeat_negative;
  logic clk, start, ready;
  invalid_checker #(.W(-1)) bad (.*);
endmodule
