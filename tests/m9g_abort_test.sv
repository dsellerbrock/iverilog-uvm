// M9G: abort property operators (IEEE 1800-2017 16.12.9):
//   accept_on(c) p / sync_accept_on(c) p  — abort to PASS the moment c holds
//   reject_on(c) p / sync_reject_on(c) p  — abort to FAIL the moment c holds
// Machine-checked via per-assertion failure counters. Stimulus is purely
// synchronous (everything toggles off the same clock), so the sampled and
// unsynced forms coincide and each assertion has a deterministic outcome.
module m9g_abort_test;
  logic clk = 0;
  logic p   = 0;    // the guarded property operand
  logic c   = 0;    // the abort condition
  int f_acc = 0, f_sacc = 0, f_rej = 0, f_srej = 0;
  int errors = 0;

  always #5 clk = ~clk;

  // accept_on(c) p : whenever c holds the attempt passes regardless of p;
  //   otherwise p must hold. We drive p high on every cycle c is low, so the
  //   property is satisfied at every cycle -> never fails.
  acc:  assert property (@(posedge clk) accept_on(c) p)       else f_acc++;
  sacc: assert property (@(posedge clk) sync_accept_on(c) p)  else f_sacc++;

  // reject_on(c) p : whenever c holds the attempt fails; otherwise p must
  //   hold. c is held low for the checked window and p is high, so no
  //   completed cycle fails.
  rej:  assert property (@(posedge clk) reject_on(c) p)       else f_rej++;
  srej: assert property (@(posedge clk) sync_reject_on(c) p)  else f_srej++;

  // Second phase drives an intentional reject: raise c so reject_on must fire.
  int f_rejfail = 0;
  rejf: assert property (@(posedge clk) reject_on(c) p)       else f_rejfail++;

  initial begin
    // Phase 1: c low, p high -> all four base assertions must hold.
    c = 0; p = 1;
    repeat (5) @(posedge clk);
    if (f_acc  != 0) begin $display("FAIL accept_on got=%0d exp=0", f_acc); errors++; end
    if (f_sacc != 0) begin $display("FAIL sync_accept_on got=%0d exp=0", f_sacc); errors++; end
    if (f_rej  != 0) begin $display("FAIL reject_on got=%0d exp=0", f_rej); errors++; end
    if (f_srej != 0) begin $display("FAIL sync_reject_on got=%0d exp=0", f_srej); errors++; end

    // Phase 2: raise c and drop p. reject_on must abort to a failure, while
    // accept_on must abort to a pass despite p being low.
    c = 1; p = 0;
    repeat (4) @(posedge clk);
    if (f_rejfail == 0) begin $display("FAIL reject_on(c) never fired with c high"); errors++; end

    // accept_on with c high must still never fail (abort-to-pass, p is low).
    if (f_acc  != 0) begin $display("FAIL accept_on fired with c high got=%0d", f_acc); errors++; end
    if (f_sacc != 0) begin $display("FAIL sync_accept_on fired with c high got=%0d", f_sacc); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
