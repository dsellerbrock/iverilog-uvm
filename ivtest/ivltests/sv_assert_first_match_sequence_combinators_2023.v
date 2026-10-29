module sv_assert_first_match_sequence_combinators;
  bit clk, a, b, c, d;
  int passes, failures;

  assert property (@(posedge clk)
    first_match((a ##1 b) or (c ##1 d))) passes++;
  else failures++;

  assert property (@(posedge clk)
    first_match((a ##1 b) and (c ##1 d))) passes++;
  else failures++;

  initial begin
    #10;
    if (passes || failures)
      $fatal(1, "first_match idle counts=%0d/%0d", passes, failures);
    $display("PASS first_match accepts sequence or/and operands");
    $finish(0);
  end
endmodule
