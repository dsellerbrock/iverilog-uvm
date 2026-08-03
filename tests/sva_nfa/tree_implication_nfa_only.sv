// IEEE 1800-2017 16.9.5/A.2.10: sequence-combinator operands of an
// implication are full sequence expressions. Exercise an `or' antecedent,
// a variable `throughout' consequent, and a combinator antecedent feeding a
// strong eventuality.
module tree_implication_nfa_only;
  logic clk = 0, a = 0, b = 0, c = 0, g = 0, y = 0;
  always #5 clk = ~clk;

  c_or: cover property (@(posedge clk) a or b |-> c);       // inst 0
  c_th: cover property (@(posedge clk) a |->
                         (g throughout y[->1]));             // inst 1
  c_nested: cover property (@(posedge clk) g |->
                             (a |-> c));                     // inst 2
  a_ev: assert property (@(posedge clk) a and b |=>
                          s_eventually(c))
          else $display("eventual FAIL at %0t", $time);      // inst 3

  initial begin
    // At t=15 both the `or' antecedent and c hold. The throughout
    // obligation starts with g high and ends when y rises at t=25.
    @(negedge clk) a=1; b=1; c=1; g=1;
    @(negedge clk) a=0; b=0; c=0; y=1;
    @(negedge clk) y=0; c=1; // discharges the nonoverlapped eventuality
    @(negedge clk) c=0;

    // A second throughout attempt loses g before y and must not count.
    @(negedge clk) a=1; g=1;
    @(negedge clk) a=0; g=0; y=1;
    @(negedge clk) y=0;
    @(negedge clk);
    $display("tree implication covers=%0d,%0d,%0d (expect 1,1,1)",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0);
    $finish(0);
  end
endmodule
