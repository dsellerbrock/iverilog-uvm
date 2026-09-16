// IEEE 1800-2017/2023 A.2.10: cycle_delay_range's constant_primary
// alternative includes a parenthesized expression, not just a bare
// literal or identifier -- `##( <expression> )`. Confirmed
// independently: slang (--std 1800-2017) accepts both `##(3+1)` and
// `##(tw+1)` (tw a property formal argument) with 0 errors, 0 warnings.
//
// Real, unmodified Caliptra formal-verification source relies on this
// exact shape (src/ecc/formal/properties/
// fv_ecc_hmac_drbg_interface_constraints.sv, line 67:
// `##(time_window+1) hmac_drbg_valid;` where time_window is a property
// formal argument). Before this fix, `##(` was rejected as a plain
// "syntax error" regardless of what was inside the parens -- even a
// pure constant like `##(1+1)` -- because delay_value_simple (the
// nonterminal shared by every K_CYCLE_DELAY use site) has no
// parenthesized-expression alternative; only a bare DEC_NUMBER,
// REALTIME, IDENTIFIER, or TIME_LITERAL. The already-existing bare
// `##tw` form (no parens) correctly reached a semantic "sorry:
// sequence cycle delays must be literal constants" diagnostic;
// `##(...)`  never reached parsing at all.
module main;
  bit clk = 0;
  bit a = 0, b = 0;
  int fails = 0;

  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  // Parenthesized constant expression at the trailing-delay position --
  // the real file's shape (a `+' expression, standing in for a formal
  // argument's arithmetic without requiring a full formal-substitution
  // scenario here).
  property p_const;
    a |-> ##(1+1) b;
  endproperty
  ap_const: assert property (p_const) else fails++;

  // Same grammar point (K_CYCLE_DELAY sva_cycle_delay_value) reached
  // through the multiclock clock-flow-boundary production instead of
  // the ordinary leading/trailing delay production -- a parenthesized
  // literal (no arithmetic, since the multiclock boundary check only
  // recognizes a literal PENumber, a separate and unrelated limitation
  // from this fix) confirms the new alternative is wired into every
  // K_CYCLE_DELAY site this fix touched, not just one.
  property p_multiclock;
    @(posedge clk) a ##(1) @(posedge clk) b;
  endproperty
  ap_mc: assert property (p_multiclock) else fails++;

  initial begin
    a = 1;
    @(posedge clk); #1;
    b = 1;
    @(posedge clk); #1;
    @(posedge clk); #1;
    if (fails != 0) begin
      $display("FAILED, fails=%0d", fails);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule
