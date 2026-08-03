// Empty-minimum consecutive repetition and a variable-length implication
// antecedent (IEEE 1800-2017 16.9.2/A.2.10).
module zero_repeat_antecedent_nfa_only;
  logic clk = 0, a = 0, b = 0, x = 0, y = 0, z = 0;
  always #5 clk = ~clk;

  cz: cover property (@(posedge clk) a |-> !b[*0:$] ##1 b); // inst 0
  cv: cover property (@(posedge clk)
                       a ##1 x[*1:$] ##1 y |=> z);           // inst 1

  initial begin
    @(negedge clk) a=1;
    @(negedge clk) a=0; b=1; x=1;
    @(negedge clk) b=0; x=1;
    @(negedge clk) x=0; y=1;
    @(negedge clk) y=0; z=1;
    @(negedge clk) z=0;
    @(negedge clk);
    $display("zero/variable covers=%0d,%0d (expect 1,1)",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
