module test;
  bit clk = 0;
  bit abort_cond, a, b;

  always #5 clk = ~clk;

  // IEEE-valid temporal property operand; the implementation currently
  // documents Boolean-only abort lowering.
  assert property (@(posedge clk) accept_on(abort_cond) (a ##1 b));

  initial begin
    #1 abort_cond = 0;
    #20 $finish;
  end
endmodule
