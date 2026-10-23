module sv_sva_subsequence_match_item;
  logic clk = 0;
  logic a = 0;
  logic b = 0;
  always #5 clk = !clk;

  property assigned_at_subsequence_endpoint;
    int x;
    a |-> ((a ##1 b), x = 1) ##1 (x == 1);
  endproperty

  assert property (@(posedge clk) assigned_at_subsequence_endpoint)
    else $fatal(1, "subsequence match-item assignment was not visible");

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);
    $display("PASSED");
    $finish(0);
  end
endmodule
