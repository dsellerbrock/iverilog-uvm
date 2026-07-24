// M6B-4: concurrent assertions sample their operands in the PREPONED
// region (IEEE 1800-2017 16.5.1) -- the values the operands held before
// any update made in the current time slot.
//
// The synthesized checker is an ordinary `always @(clk)' process, so it
// used to read operands live, in the Active region. A blocking write in
// the same time slot as the clock edge was therefore visible to the
// assertion and the verdict flipped, with no diagnostic. Operands
// written by NBA happened to look right, but only because NBA updates
// land after edge detection -- nothing was actually sampled.
//
// The checker now reads each whole-signal operand through
// $ivl_clocking_sample (%load/preponed), with the matching
// $ivl_clocking_hist_on prologue, so the sampled value is the one from
// the start of the time step regardless of when in the step the checker
// runs.
//
// Every case below drives the clock and the operands from ONE process,
// so the Active-region ordering is fixed and the result cannot be
// blamed on a race between processes.
module m6b4_assert_preponed_sample_test;

  parameter int LIMIT = 5;

  bit          clk = 0;
  bit          a = 0, b = 0;
  logic [7:0]  wide = 0;
  logic [7:0]  lim_in = 0;
  logic        nba_v = 0;

  int vac_fails = 0, vac_passes = 0;
  int wide_fails = 0, wide_passes = 0;
  int nba_fails = 0, nba_passes = 0;
  int par_fails = 0, par_passes = 0;
  int past_fails = 0, past_passes = 0;

  // 1. Antecedent written blocking in the same slot as the edge. The
  //    preponed value of `a' is 0, so the attempt is vacuous: neither a
  //    pass nor a fail. Reading `a' live saw 1 and reported a failure.
  ap_vac: assert property (@(posedge clk) a |-> b)
            vac_passes++; else vac_fails++;

  // 2. A multi-bit operand -- also covers the sampled read being typed
  //    at the operand's own width rather than a default 32.
  ap_wide: assert property (@(posedge clk) wide == 8'h00)
             wide_passes++; else wide_fails++;

  // 3. An operand updated by NBA in the same slot must also read 0.
  ap_nba: assert property (@(posedge clk) nba_v == 0)
            nba_passes++; else nba_fails++;

  // 4. A parameter operand has no driven-value history; its preponed
  //    value is simply its value. (This shape used to emit no code for
  //    the operand at all and crashed vvp on a stack underflow.)
  ap_par: assert property (@(posedge clk) lim_in <= LIMIT)
            par_passes++; else par_fails++;

  // 5. $past must report the sampled value from the previous tick.
  ap_past: assert property (@(posedge clk) $past(a) == 0)
             past_passes++; else past_fails++;

  always @(posedge clk) nba_v <= 1;   // NBA in the same slot as the edge

  initial begin
    int errors = 0;

    // t=5: every operand is written in the Active region BEFORE the
    // edge, in the same single-threaded sequence.
    #5;
    a      = 1;
    wide   = 8'hAA;
    lim_in = 8'd3;
    clk    = 1;          // the only posedge in this test

    #5 clk = 0;
    #5;

    if (vac_fails != 0 || vac_passes != 0) begin
      $display("FAIL antecedent not vacuous: fails=%0d passes=%0d (expected 0/0)",
               vac_fails, vac_passes);
      errors++;
    end
    if (wide_fails != 0 || wide_passes != 1) begin
      $display("FAIL wide operand: fails=%0d passes=%0d (expected 0/1)",
               wide_fails, wide_passes);
      errors++;
    end
    if (nba_fails != 0 || nba_passes != 1) begin
      $display("FAIL NBA operand: fails=%0d passes=%0d (expected 0/1)",
               nba_fails, nba_passes);
      errors++;
    end
    if (par_fails != 0 || par_passes != 1) begin
      $display("FAIL parameter operand: fails=%0d passes=%0d (expected 0/1)",
               par_fails, par_passes);
      errors++;
    end
    if (past_fails != 0 || past_passes != 1) begin
      $display("FAIL $past operand: fails=%0d passes=%0d (expected 0/1)",
               past_fails, past_passes);
      errors++;
    end

    if (errors == 0) $display("PASS m6b4_assert_preponed_sample_test");
    $finish(0);
  end
endmodule
