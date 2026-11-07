// IEEE 1800-2017/2023 16.13.6: an empty match of a variable-length sequence
// does not make triggered/matched true. The sequence has no clock of its
// own; the assertions supply it.
module issue1190_endpoint_empty_inferred;
  logic clk = 0, a = 0;
  int fails = 0;
  always #5 clk = ~clk;
  sequence maybe_empty; a[*0:1]; endsequence
  p_trigger: assert property (@(posedge clk) !maybe_empty.triggered) else fails++;
  p_match: assert property (@(posedge clk) !maybe_empty.matched) else fails++;
  initial begin
    #60;
    if (fails == 0) $display("PASSED");
    else $display("FAILED: fails=%0d", fails);
    $finish;
  end
endmodule
