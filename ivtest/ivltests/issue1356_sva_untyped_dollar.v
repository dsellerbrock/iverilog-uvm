module issue1356_sva_untyped_dollar;
  bit clk;
  logic a, b;
  int direct_passes, forward_passes, failures;

  sequence until_b(x, limit);
    x ##[1:limit] b;
  endsequence

  sequence inner(limit);
    a ##[1:limit] b;
  endsequence

  sequence outer(bound);
    inner(bound);
  endsequence

  assert property (@(posedge clk) until_b(a, $)) direct_passes++;
  else failures++;

  assert property (@(posedge clk) outer($)) forward_passes++;
  else failures++;

  initial begin
    #3 a = 1;
    #1;
    clk = 1;
    #1 $assertoff(0);
    a = 0;
    #9 b = 1;
    clk = 0;
    #1 clk = 1;
    #1;
    if (direct_passes != 1 || forward_passes != 1 || failures)
      $fatal(1, "dollar-bound pass/forward/fail=%0d/%0d/%0d",
             direct_passes, forward_passes, failures);
    $display("PASS untyped dollar sequence upper bounds");
    $finish(0);
  end
endmodule
