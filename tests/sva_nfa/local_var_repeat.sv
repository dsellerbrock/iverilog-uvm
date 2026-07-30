// C5-1: SVA local variable assigned inside a consecutive repetition
// (IEEE 1800-2017 16.10). The pre-fix pform repetition clone shared the
// lv_rhs expression pointer across the cloned steps, so freeing the
// clones double-freed the tree and iverilog SEGFAULTED at compile.
// The fix deep-clones lv_rhs per repetition step. Semantics pinned:
// the local var is reassigned on EVERY repetition step, so after
// (a, v = d)[*3] it must hold d from the THIRD sampled step, and the
// comparison one cycle later must see that value. The match counter in
// the verdict stream proves the value, not just crash-freedom.
module local_var_repeat;
  logic clk = 0, a = 0, c = 0;
  logic [7:0] d = 0;
  always #5 clk = ~clk;

  cv: cover property (@(posedge clk)
        (a, v = d)[*3] ##1 (c && v == 8'd30));

  initial begin
    @(negedge clk) a = 1; d = 10;   // sampled @15: rep 1, v = 10
    @(negedge clk) d = 20;          // sampled @25: rep 2, v = 20
    @(negedge clk) d = 30;          // sampled @35: rep 3, v = 30
    @(negedge clk) a = 0; c = 1;    // sampled @45: c true, v == 30 -> match
    @(negedge clk) c = 0;
    @(negedge clk);
    $display("lv cnt=%0d (expect 1)", _ivl_sva0_cnt0);
    $finish(0);
  end
endmodule
