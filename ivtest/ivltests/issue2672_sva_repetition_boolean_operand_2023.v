module issue2672_sva_repetition_boolean_operand;
  bit clk = 0, stop = 0, put = 0, go = 1;
  always #5 clk = ~clk;

  assert property (@(posedge clk) if (go) put[->2]);
  assert property (@(posedge clk) always put[->1]);
  assert property (@(posedge clk) nexttime put[->1]);
  assert property (@(posedge clk) reject_on(stop) put[->2]);
  assert property (@(posedge clk) if (go) put[=2]);
  assert property (@(posedge clk) always put[=1]);
  assert property (@(posedge clk) nexttime put[=1]);
  assert property (@(posedge clk) reject_on(stop) put[=2]);
endmodule
