module sv_assert_no_match_antecedent;
  logic clk = 0, b = 1;
  always #5 clk = ~clk;

  assert_overlap: assert property (@(posedge clk)
    (1'b1 intersect (1'b1 ##1 1'b1)) |-> b);
  assert_nonoverlap: assert property (@(posedge clk)
    (1'b1 intersect (1'b1 ##1 1'b1)) |=> b);

  initial begin
    repeat (2) @(negedge clk);
    $display("no-match-antecedents-compiled-and-ran");
    $finish(0);
  end
endmodule
