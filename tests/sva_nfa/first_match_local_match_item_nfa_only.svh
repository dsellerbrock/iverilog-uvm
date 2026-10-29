// IEEE 1800-2017/2023 16.9.8 and 16.10: the first-match assignment flows
// to the continuation with the value from the earliest endpoint. The ##2
// check runs after the later candidate endpoint, which must not overwrite it.
module first_match_local_match_item_nfa_only;
  logic clk = 0, a = 0, b = 0;
  int failures = 0;
  always #5 clk = ~clk;

  property p_first_match;
    int selected_time;
    @(posedge clk) a |->
      (first_match(a ##[1:2] b, selected_time = $time)
       ##2 (selected_time == 25));
  endproperty
  assert property (p_first_match) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);

    if (failures != 0)
      $fatal(1, "first_match local assignment failures=%0d", failures);
    $display("PASSED: first_match local assignment reaches the continuation");
    $finish(0);
  end
endmodule
