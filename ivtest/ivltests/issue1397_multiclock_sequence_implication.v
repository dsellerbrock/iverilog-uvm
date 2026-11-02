module issue1397_multiclock_sequence_implication;
  logic clk = 0, clk1 = 0, clk2 = 0;
  logic a = 1, b = 1, c = 0, d = 0;
  logic x = 1, u = 1, v = 0;
  integer matched_antecedent_failures = 0;
  integer vacuous_antecedent_failures = 0;

  always #5 clk = ~clk;
  always #7 clk1 = ~clk1;
  always #11 clk2 = ~clk2;

  sequence s1;
    a ##1 b;
  endsequence
  sequence s2;
    c ##1 d;
  endsequence
  sequence no_match;
    u ##1 v;
  endsequence

  property multiclock_implication;
    @(posedge clk) a ##1 @(posedge clk1) s1
      |=> @(posedge clk2) s2;
  endproperty

  property vacuous_multiclock_implication;
    @(posedge clk) x ##1 @(posedge clk1) no_match
      |=> @(posedge clk2) s2;
  endproperty

  assert property (multiclock_implication)
    else matched_antecedent_failures++;
  assert property (vacuous_multiclock_implication)
    else vacuous_antecedent_failures++;

  initial begin
    #500;
    if (matched_antecedent_failures == 0)
      $fatal(1, "consequent did not fail after a complete multiclock antecedent");
    if (vacuous_antecedent_failures != 0)
      $fatal(1, "a mismatch in the multiclock antecedent was not vacuous");
    $display("PASSED");
    $display("issue 1397 multiclock antecedent implication");
    $finish;
  end
endmodule
