// IEEE 1800-2017/2023 16.9.5-16.9.6 and 16.12.7: `and` accepts
// different sequence lengths; `intersect` requires equal match lengths.
// Unequal fixed-length intersect operands are legal and have no matches.
module intersect_unequal_lengths_nfa_only;
  logic clk = 0;
  logic and_a = 0, and_b = 0, and_c = 0, and_d = 0;
  logic eq_a = 0, eq_b = 0, eq_c = 0, eq_d = 0;
  logic ix_a = 0, ix_b = 0, ix_c = 0, ix_d = 0;
  logic go = 0, cons_a = 0, cons_b = 0, cons_c = 0, cons_d = 0;
  int antecedent_failures = 0, consequent_failures = 0;
  always #5 clk = ~clk;

  // Distinct match endpoints are legal for `and` and complete at the later
  // endpoint. Equal-length intersect remains a positive control.
  cover property (@(posedge clk) (and_a ##1 and_b) and (and_c ##2 and_d));
  cover property (@(posedge clk) (eq_a ##1 eq_b) intersect (eq_c ##1 eq_d));

  // Both direct sequence and implication consequent stay unmatched when the
  // intersect operands have different fixed lengths.
  cover property (@(posedge clk) (ix_a ##1 ix_b) intersect (ix_c ##2 ix_d));
  cover property (@(posedge clk) go |->
                  ((cons_a ##1 cons_b) intersect (cons_c ##2 cons_d)));

  // An empty intersect antecedent is vacuous; the same empty sequence as a
  // consequent fails after the antecedent matches.
  assert property (@(posedge clk)
                   ((ix_a ##1 ix_b) intersect (ix_c ##2 ix_d)) |-> 1'b0)
    else antecedent_failures++;
  assert property (@(posedge clk) go |->
                   ((cons_a ##1 cons_b) intersect (cons_c ##2 cons_d)))
    else consequent_failures++;

  initial begin
    @(negedge clk);
    and_a=1; and_c=1; eq_a=1; eq_c=1; ix_a=1; ix_c=1;
    go=1; cons_a=1; cons_c=1;
    @(negedge clk);
    and_a=0; and_c=0; and_b=1; eq_a=0; eq_c=0; eq_b=1; eq_d=1;
    ix_a=0; ix_c=0; ix_b=1; cons_a=0; cons_c=0; cons_b=1; go=0;
    @(negedge clk);
    and_b=0; and_d=1; ix_b=0; ix_d=1; cons_b=0; cons_d=1;
    @(negedge clk);
    and_d=0; ix_d=0; cons_d=0;
    @(negedge clk);
    $display("covers=%0d,%0d,%0d,%0d failures=%0d,%0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0,
             _ivl_sva3_cnt0, antecedent_failures, consequent_failures);
    if (_ivl_sva0_cnt0 == 1 && _ivl_sva1_cnt0 == 1
        && _ivl_sva2_cnt0 == 0 && _ivl_sva3_cnt0 == 0
        && antecedent_failures == 0 && consequent_failures == 1)
      $display("PASSED");
    else
      $display("FAILED");
    $finish(0);
  end
endmodule
