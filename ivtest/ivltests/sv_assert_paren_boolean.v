// A property or sequence whose FIRST token is `(' must still be able to
// continue as an ordinary expression.
//
// `(a) && b', `(x == 1) || (y == 2)' and `(a) ? b : c' contain no sequence
// operators at all -- they are plain booleans that happen to start with a
// parenthesis. They used to be syntax errors inside `assert property',
// because the leading `(' committed the parse to the parenthesized
// SUB-SEQUENCE rule and no expression operator could follow the `)'.
//
// The counterpart -- parens that really do hold sequence structure --
// must keep parsing AND matching as sequences, so both directions are
// checked here.

module sv_assert_paren_boolean;

  logic clk = 0;
  logic a = 0, b = 0, c = 0;
  logic never_true = 0;
  logic [3:0] x = 0, y = 0;

  int and_fails = 0, or_fails = 0, tern_fails = 0, cmp_fails = 0;
  int seq_matches = 0;

  always #5 clk = ~clk;

  // Leading paren followed by expression operators.
  ParenAnd_A:  assert property (@(posedge clk) (a) && b)        else and_fails++;
  ParenOr_A:   assert property (@(posedge clk) (a) || (b))      else or_fails++;
  ParenTern_A: assert property (@(posedge clk) (a) ? b : c)     else tern_fails++;
  ParenCmp_A:  assert property (@(posedge clk) (x == 4) && (y == 5)) else cmp_fails++;

  // Leading paren holding real sequence structure. `never_true' is held
  // low, so the consequent always fails and the failure count IS the
  // number of times the parenthesized sequence matched. That proves the
  // sequence is still being evaluated as a sequence, not just parsed.
  ParenSeq_A: assert property (@(posedge clk) (a ##1 b) |-> never_true)
    else seq_matches++;

  initial begin
    // Cycle 1: every boolean assertion holds.
    @(negedge clk); a = 1; b = 1; c = 1; x = 4; y = 5;
    // Cycle 2: b low while a high -> And/Or/Tern/Cmp see a false term,
    //          and (a ##1 b) starting at cycle 2 will match at cycle 3.
    @(negedge clk); b = 0; x = 0; y = 0;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); a = 1; b = 1; c = 1; x = 4; y = 5;
    repeat (4) @(negedge clk);

    // Each boolean assertion must have fired at least once: that proves
    // it was live, not merely accepted and discarded.
    if (and_fails == 0)
      $display("FAILED -- `(a) && b' never fired; it was accepted but not evaluated");
    else if (or_fails == 0)
      $display("FAILED -- `(a) || (b)' never fired; it was accepted but not evaluated");
    else if (tern_fails == 0)
      $display("FAILED -- `(a) ? b : c' never fired; it was accepted but not evaluated");
    else if (cmp_fails == 0)
      $display("FAILED -- `(x == 4) && (y == 5)' never fired; it was accepted but not evaluated");
    else if (seq_matches == 0)
      $display("FAILED -- the parenthesized SEQUENCE `(a ##1 b)' stopped matching");
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
