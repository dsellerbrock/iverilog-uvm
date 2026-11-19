module issue3851_grouped_concat_bad;
  parameter int delay = 1;
  bit clk, a, b;

  assert property (@(posedge clk) a ##delay (a and b));
  assert property (@(posedge clk) a ##1 (((a |-> b) and a)));
  assert property (@(posedge clk) ((a[*0]) or (b[*0])) ##0 b);
  assert property (@(posedge clk) ((a[*0]) or (b[*0])) ##1 (a[*0]));
endmodule
