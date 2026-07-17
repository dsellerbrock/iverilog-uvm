// M9C-live: SVA liveness operators nexttime / s_nexttime / s_eventually
// (IEEE 1800-2017 16.12.2, 16.12.5). Previously loud sorries.
//
//  nexttime p    — p must hold at the next cycle. Aggregated over the
//                  per-clock attempts this is "p every cycle after the
//                  first"; fails at cycle T>=1 when !p (a $past(1,1)
//                  guard suppresses the first cycle).
//  s_nexttime p  — same, plus the final attempt has no next cycle, so a
//                  strong end-of-simulation failure is reported once.
//  s_eventually p— p must hold at least once; a strong end-of-simulation
//                  failure is reported if it never did.
//
// Machine-checked: the per-cycle nexttime / s_nexttime fail counts.
// The end-of-simulation strong $errors (s_nexttime's last-attempt and
// s_eventually q's never-seen) appear after the PASS line as evidence.
module m9c_live_test_top;
  logic clk = 0, p = 1, q = 0;   // q is never asserted
  int f_nt = 0, f_snt = 0;
  int errors = 0;
  always #5 clk = ~clk;

  nt:  assert property (@(posedge clk) nexttime     p) else f_nt++;
  snt: assert property (@(posedge clk) s_nexttime   p) else f_snt++;
  se:  assert property (@(posedge clk) s_eventually p) else ;  // p pulses -> OK
  sen: assert property (@(posedge clk) s_eventually q) else ;  // q never -> liveness $error

  // p profile over 8 cycles; nexttime fails at T>=1 where p is 0.
  //  idx: 0 1 2 3 4 5 6 7
  //  p:   1 1 0 1 0 0 1 1   -> zeros at idx 2,4,5 (all >=1) -> 3 fails
  localparam int N = 8;
  bit [0:N-1] pv = 8'b1101_0011;

  task check(string w, int got, int exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0d exp=%0d", w, got, exp);
      errors++;
    end
  endtask

  initial begin
    for (int i = 0; i < N; i++) begin
      p = pv[i]; q = 0;
      @(posedge clk); #1;
    end
    // Settle with p high (no further nexttime failures).
    p = 1; q = 0; @(posedge clk); #1;
    p = 1; q = 0; @(posedge clk); #1;

    check("nexttime",   f_nt,  3);
    check("s_nexttime", f_snt, 3);   // per-cycle part equals nexttime

    if (errors == 0) $display("PASS: m9c liveness (strong end-of-sim $errors expected next)");
    else $display("FAIL: m9c liveness (%0d errors)", errors);
    $finish(0);
  end
endmodule
