// IEEE 1800-2017 A.2.10: the consequent of an implication is a
// `property_expr', not merely a sequence, so a liveness operator may
// appear there:
//
//   assert property (@(posedge clk) req |-> s_eventually(ack));
//
// The grammar only had `sva_seq_expr |-> sva_seq_expr', so this was a
// syntax error. It is the shape OpenTitan's GENERATED CSR assertions emit
// for every comportable IP.
//
// Semantics checked here (the collapse the lowering relies on): for every
// antecedent match, the consequent must hold at some cycle at or after
// that match -- strictly after for `|=>'. The obligation from the LAST
// match is the strongest, so one pending bit suffices; it is reported at
// end of simulation if still set. An antecedent that never matches passes
// vacuously.
//
// Each case gets its own signal pair so one failing case cannot mask
// another. The counters are checked in a final block declared after the
// assertions, so it runs after their end-of-simulation checks.

module sv_assert_impl_s_eventually;

  logic clk = 0;
  always #5 clk = ~clk;

  logic a1 = 0, b1 = 0;   // |->  satisfied later          -> must NOT fire
  logic a2 = 0, b2 = 0;   // |->  never satisfied          -> MUST fire
  logic a3 = 0, b3 = 0;   // |->  satisfied same cycle     -> must NOT fire
  logic a4 = 0, b4 = 0;   // |=>  only same cycle          -> MUST fire
  logic a5 = 0, b5 = 0;   // |=>  satisfied later          -> must NOT fire
  logic a6 = 0, b6 = 0;   // |->  antecedent never matches -> must NOT fire

  int f1 = 0, f2 = 0, f3 = 0, f4 = 0, f5 = 0, f6 = 0;

  Ov_Later_A:  assert property (@(posedge clk) a1 |-> s_eventually(b1)) else f1++;
  Ov_Never_A:  assert property (@(posedge clk) a2 |-> s_eventually(b2)) else f2++;
  Ov_Same_A:   assert property (@(posedge clk) a3 |-> s_eventually(b3)) else f3++;
  Nov_Same_A:  assert property (@(posedge clk) a4 |=> s_eventually(b4)) else f4++;
  Nov_Later_A: assert property (@(posedge clk) a5 |=> s_eventually(b5)) else f5++;
  Ov_Vacuous_A:assert property (@(posedge clk) a6 |-> s_eventually(b6)) else f6++;

  initial begin
    @(negedge clk);

    // Case 1: antecedent now, consequent three cycles later.
    a1 = 1; @(negedge clk); a1 = 0;
    repeat (2) @(negedge clk);
    b1 = 1; @(negedge clk); b1 = 0;

    // Case 2: antecedent only; b2 stays low forever.
    a2 = 1; @(negedge clk); a2 = 0;

    // Case 3: antecedent and consequent in the SAME cycle. `|->' is
    // overlapped, so this discharges the obligation.
    a3 = 1; b3 = 1; @(negedge clk); a3 = 0; b3 = 0;

    // Case 4: same cycle only. `|=>' is non-overlapped, so the b4 in the
    // match cycle does NOT discharge it and nothing follows.
    a4 = 1; b4 = 1; @(negedge clk); a4 = 0; b4 = 0;

    // Case 5: antecedent, then consequent two cycles later.
    a5 = 1; @(negedge clk); a5 = 0;
    @(negedge clk);
    b5 = 1; @(negedge clk); b5 = 0;

    // Case 6: a6 never asserted. b6 never asserted either -- vacuous pass.

    repeat (4) @(negedge clk);
    $finish(0);
  end

  // Declared after the assertions so it runs after their end-of-simulation
  // obligations have been settled.
  int errors = 0;

  final begin
    if (f1 != 0) begin
      $display("FAILED -- |-> with a later consequent fired (%0d)", f1);
      errors++;
    end
    if (f2 != 1) begin
      $display("FAILED -- |-> with a consequent that never holds fired %0d times, want 1", f2);
      errors++;
    end
    if (f3 != 0) begin
      $display("FAILED -- |-> did not accept a same-cycle consequent (fired %0d)", f3);
      errors++;
    end
    if (f4 != 1) begin
      $display("FAILED -- |=> wrongly accepted a same-cycle consequent (fired %0d, want 1)", f4);
      errors++;
    end
    if (f5 != 0) begin
      $display("FAILED -- |=> with a later consequent fired (%0d)", f5);
      errors++;
    end
    if (f6 != 0) begin
      $display("FAILED -- an antecedent that never matched fired (%0d)", f6);
      errors++;
    end
    if (errors == 0) $display("PASSED");
  end

endmodule
