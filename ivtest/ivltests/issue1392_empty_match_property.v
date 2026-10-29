module issue1392_empty_match_property;
  logic clk = 0;
  logic a = 1;
  always #5 clk = ~clk;

  assert property (@(posedge clk) a[*0:2]);
endmodule
