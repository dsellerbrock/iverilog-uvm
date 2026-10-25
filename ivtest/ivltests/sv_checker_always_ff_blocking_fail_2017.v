checker c(logic clk);
  bit q;
  always_ff @(posedge clk) q = 1'b1;
endchecker
module sv_checker_always_ff_blocking_fail;
  logic clk = 0;
  c i(clk);
endmodule
