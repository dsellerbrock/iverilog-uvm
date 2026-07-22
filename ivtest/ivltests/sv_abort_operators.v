// SVA abort property operators (IEEE 1800-2017 16.12.9):
//   accept_on(c) p / sync_accept_on(c) p  — abort the attempt to a PASS the
//     moment the abort condition c holds; otherwise the boolean p must hold.
//   reject_on(c) p / sync_reject_on(c) p  — abort the attempt to a FAIL the
//     moment c holds; otherwise p must hold.
//
// For a single-cycle boolean operand this collapses to a per-cycle check:
//   reject_on(c) p -> fail on (c | !p);  accept_on(c) p -> fail on (!c & !p).
// Stimulus is purely synchronous, so the sampled and unsynced forms coincide
// and each assertion has a deterministic outcome. Self-checking: prints
// PASSED only when every assertion behaved as required.
module sv_abort_operators;
  logic clk = 0;
  logic p   = 0;
  logic c   = 0;
  int f_acc = 0, f_sacc = 0, f_rej = 0, f_srej = 0, f_rejfail = 0;
  int errors = 0;

  always #5 clk = ~clk;

  acc:  assert property (@(posedge clk) accept_on(c) p)       else f_acc++;
  sacc: assert property (@(posedge clk) sync_accept_on(c) p)  else f_sacc++;
  rej:  assert property (@(posedge clk) reject_on(c) p)       else f_rej++;
  srej: assert property (@(posedge clk) sync_reject_on(c) p)  else f_srej++;
  rejf: assert property (@(posedge clk) reject_on(c) p)       else f_rejfail++;

  initial begin
    // Phase 1: c low, p high -> every base assertion holds.
    c = 0; p = 1;
    repeat (5) @(posedge clk);
    if (f_acc  != 0) begin $display("FAILED accept_on got=%0d exp=0", f_acc); errors++; end
    if (f_sacc != 0) begin $display("FAILED sync_accept_on got=%0d exp=0", f_sacc); errors++; end
    if (f_rej  != 0) begin $display("FAILED reject_on got=%0d exp=0", f_rej); errors++; end
    if (f_srej != 0) begin $display("FAILED sync_reject_on got=%0d exp=0", f_srej); errors++; end

    // Phase 2: raise c, drop p. reject_on must abort to a failure; accept_on
    // must abort to a pass despite p being low.
    c = 1; p = 0;
    repeat (4) @(posedge clk);
    if (f_rejfail == 0) begin $display("FAILED reject_on never fired with c high"); errors++; end
    if (f_acc  != 0) begin $display("FAILED accept_on fired with c high got=%0d", f_acc); errors++; end
    if (f_sacc != 0) begin $display("FAILED sync_accept_on fired with c high got=%0d", f_sacc); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
