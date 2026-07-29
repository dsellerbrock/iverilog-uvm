// IEEE 1800-2017 A.2.10: `property_expr ::= ( property_expr )'.
//
// A fully parenthesized property is what every assertion macro that wraps
// its argument produces. OpenTitan's `ASSERT' macro, for example, expands
// to
//     name: assert property (@(posedge clk) disable iff (...) (__prop))
// so the whole property -- implication and all -- arrives inside parens.
// That shape used to be a syntax error, which made every OpenTitan
// assertion unparseable.
//
// This checks the parenthesized form is accepted AND that it evaluates
// identically to the unparenthesized one: both must fire on the same
// clock edges and the same number of times. A parse-only check would not
// catch an implementation that accepted the parens and then dropped the
// property.

module sv_assert_paren_property;

  logic clk = 0, rst_n = 0, a = 0, b = 0;

  int paren_fails = 0;
  int bare_fails  = 0;

  always #5 clk = ~clk;

  // Parenthesized property, exactly the macro-expanded shape.
  ParenProp_A: assert property (@(posedge clk) disable iff ((!rst_n) !== '0) (a |=> b))
    else paren_fails++;

  // Same property, written without the outer parens. Control.
  BareProp_A: assert property (@(posedge clk) disable iff ((!rst_n) !== '0) a |=> b)
    else bare_fails++;

  // Parens that hold a SEQUENCE rather than a property must keep working.
  int seq_fails = 0;
  SeqParen_A: assert property (@(posedge clk) disable iff ((!rst_n) !== '0) (a ##1 b) |-> 1'b1)
    else seq_fails++;

  initial begin
    #12 rst_n = 1;
    // a high with b low next cycle -> both assertions must fail.
    @(negedge clk); a = 1; b = 0;
    @(negedge clk); a = 0; b = 0;
    // a high with b high next cycle -> neither may fail.
    @(negedge clk); a = 1; b = 0;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); a = 0; b = 0;
    repeat (4) @(negedge clk);

    if (bare_fails == 0)
      $display("FAILED -- the control assertion never fired; the test itself is broken");
    else if (paren_fails != bare_fails)
      $display("FAILED -- paren=%0d bare=%0d; the parenthesized property was not evaluated the same",
               paren_fails, bare_fails);
    else if (seq_fails != 0)
      $display("FAILED -- a parenthesized SEQUENCE regressed (%0d unexpected fails)", seq_fails);
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
