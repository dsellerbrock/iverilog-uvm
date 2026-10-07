// IEEE 1800-2023 16.12.7: a nested property consequent starts at the end
// point of each outer antecedent match, even when that antecedent spans ticks.
module nested_multicycle_implication_nfa_only;
  logic clk = 0, a = 0, b = 0, c = 0, e = 0, d = 0;
  logic x = 0, y = 0, u = 0, w = 0, v = 0;
  int failures = 0;
  always #5 clk = ~clk;

  nested: assert property (@(posedge clk) (a ##1 b) |-> ((c ##1 e) |=> d))
    else failures++;
  nested_nonoverlapped:
    assert property (@(posedge clk) (x ##1 y) |=> ((u ##1 w) |-> v))
      else failures++;

  initial begin
    @(negedge clk) a = 1; x = 1;
    @(negedge clk) a = 0; b = 1; c = 1; x = 0; y = 1;
    @(negedge clk) b = 0; c = 0; e = 1; y = 0; u = 1;
    @(negedge clk) e = 0; u = 0; w = 1;
    @(negedge clk) w = 0;
    $display("nested multi-cycle failures=%0d (expect 2)", failures);
    $finish(0);
  end
endmodule
