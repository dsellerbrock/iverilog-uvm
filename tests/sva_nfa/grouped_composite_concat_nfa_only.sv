// IEEE 1800-2017 16.9.1/16.9.5: a parenthesized composite sequence is
// still a sequence_expr and may continue through ##0.  The outer grouping
// pair used to commit the `and' tree as a complete property, so both exact
// upstream shapes below died at ##0 with a syntax error.  Fixed and ranged
// operands exercise the same grouped declaration route and the latter also
// proves that the continuation preserves the NFA tree rather than flattening
// either side.
module grouped_composite_concat_nfa_only;
  logic clk = 0;
  logic a = 0, b = 0, c = 0, d = 0;
  logic e = 0, f = 0, g = 0, h = 0;
  always #5 clk = ~clk;

  sequence fixed_and_concat;
    @(posedge clk) ((a ##1 b) and (a ##2 c)) ##0 d;
  endsequence

  sequence ranged_and_concat;
    @(posedge clk) ((e ##[1:2] f) and (e ##[1:3] g)) ##0 h;
  endsequence

  cf: cover property (fixed_and_concat);
  cr: cover property (ranged_and_concat);

  initial begin
    // One fixed match: a@15, b@25, and c/d@35.  ##0 requires d at
    // the later `and' endpoint, not one tick after it.
    @(negedge clk) a = 1;
    @(negedge clk) a = 0; b = 1;
    @(negedge clk) b = 0; c = 1; d = 1;
    @(negedge clk) c = 0; d = 0;

    // One ranged match: e@55, f at offset 2, and g/h at offset 3.
    // No other window endpoint is true, so there is exactly one match.
    @(negedge clk) e = 1;
    @(negedge clk) e = 0;
    @(negedge clk) f = 1;
    @(negedge clk) f = 0; g = 1; h = 1;
    @(negedge clk) g = 0; h = 0;

    repeat (2) @(negedge clk);
    $display("grouped composite counts fixed=%0d ranged=%0d (expect 1/1)",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
