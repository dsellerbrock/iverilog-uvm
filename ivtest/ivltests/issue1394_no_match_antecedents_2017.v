module issue1394_no_match_antecedents;
  logic clk = 0, b = 1;
  always #5 clk = ~clk;

  assert property (@(posedge clk)
    (1'b1 intersect (1'b1 ##1 1'b1)) |-> b);
  assert property (@(posedge clk)
    (1'b1 intersect (1'b1 ##1 1'b1)) |=> b);
endmodule
