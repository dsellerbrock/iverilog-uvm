// IEEE 1800-2017 A.2.10: the consequent of an implication is a
// `property_expr', and `( property_expr )' is itself one -- so
// `a |-> ( b ##1 c )' is legal and means exactly what the
// unparenthesized form means: the parens are pure grouping.
//
// Accepting the parenthesized shape must not change what it CHECKS.
// This pins the observable pass/fail counts of three spellings that
// must agree cycle for cycle: unparenthesized, parenthesized, and
// doubly parenthesized. Each sees one satisfied attempt and one
// violated attempt.
module sva_paren_seq_conseq;

  reg clk = 0;
  reg a = 0, b = 0, c = 0;

  integer bare_pass = 0, bare_fail = 0;
  integer par_pass  = 0, par_fail  = 0;
  integer par2_pass = 0, par2_fail = 0;

  always #5 clk = ~clk;

  ap_bare: assert property (@(posedge clk) a |-> b ##1 c)
    bare_pass = bare_pass + 1; else bare_fail = bare_fail + 1;

  ap_par: assert property (@(posedge clk) a |-> (b ##1 c))
    par_pass = par_pass + 1; else par_fail = par_fail + 1;

  ap_par2: assert property (@(posedge clk) a |-> ((b ##1 c)))
    par2_pass = par2_pass + 1; else par2_fail = par2_fail + 1;

  initial begin
    // Drive on the negedge so every value is settled at the posedge.
    @(negedge clk); a = 1; b = 1; c = 0;   // posedge: attempt starts
    @(negedge clk); a = 0; b = 0; c = 1;   // posedge: c holds  -> pass
    @(negedge clk); a = 1; b = 1; c = 0;   // posedge: attempt starts
    @(negedge clk); a = 0; b = 0; c = 0;   // posedge: c absent -> fail
    @(negedge clk); a = 0; b = 0; c = 0;
    @(negedge clk);
    @(negedge clk);

    $display("bare  pass=%0d fail=%0d", bare_pass, bare_fail);
    $display("par   pass=%0d fail=%0d", par_pass,  par_fail);
    $display("par2  pass=%0d fail=%0d", par2_pass, par2_fail);

    if (bare_pass === 1 && bare_fail === 1 &&
        par_pass  === 1 && par_fail  === 1 &&
        par2_pass === 1 && par2_fail === 1)
      $display("PASSED");
    else
      $display("FAILED");
    $finish;
  end

endmodule
