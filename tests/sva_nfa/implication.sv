// M9-NFA dual-run seed: |=> and a fixed-sequence antecedent |->
// (non-overlapped consequent) through the composite automaton.
module implication;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  i1: assert property (@(posedge clk) a |=> b)
        $display("i1 PASS at %0t", $time);
        else $display("i1 FAIL at %0t", $time);
  i2: assert property (@(posedge clk) a ##1 b |-> ##1 c)
        $display("i2 PASS at %0t", $time);
        else $display("i2 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1;            // a@15
    @(negedge clk) a = 0; b = 1;     // b@25: i1 pass@25; i2 ante done@25
    @(negedge clk) b = 0; c = 1;     // c@35: i2 pass@35
    @(negedge clk) c = 0;
    @(negedge clk) a = 1;            // a@55
    @(negedge clk) a = 0; b = 1;     // b@65: i1 pass; i2 ante done
    @(negedge clk) b = 0;            // c@75 = 0: i2 FAIL@75
    @(negedge clk) a = 1;            // a@85
    @(negedge clk) a = 0;            // b@95 = 0: i1 FAIL@95 (i2 vacuous)
    @(negedge clk);
    $finish(0);
  end
endmodule
