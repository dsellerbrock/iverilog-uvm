// M9F: bounded liveness/safety property operators (IEEE 1800-2017 16.12.6-.7):
//   always p / always [m:n] p / s_always [m:n] p  — safety
//   eventually [m:n] p / s_eventually [m:n] p      — bounded liveness
// Machine-checked via per-assertion failure counters. The PASS assertions use
// a signal held at 1, so no window can fail; the FAIL assertion uses a signal
// held at 0, so every completed [1:2] window fails at least once.
module m9f_bounded_live_test;
  logic clk = 0;
  logic a = 1;    // held high -> all safety/liveness windows satisfied
  logic z = 0;    // held low  -> bounded eventually can never be satisfied
  int f_alw = 0, f_balw = 0, f_salw = 0, f_ev = 0, f_sev = 0, f_evfail = 0;
  int errors = 0;

  always #5 clk = ~clk;

  // Safety: p holds at every cycle (a is always 1).
  alw:  assert property (@(posedge clk) always a)             else f_alw++;
  balw: assert property (@(posedge clk) always [1:3] a)       else f_balw++;
  salw: assert property (@(posedge clk) s_always [1:3] a)     else f_salw++;
  // Bounded liveness: p holds within the window (a is always 1).
  ev:   assert property (@(posedge clk) eventually [0:3] a)   else f_ev++;
  sev:  assert property (@(posedge clk) s_eventually [1:3] a) else f_sev++;
  // Intentional failure: z never holds, so every [1:2] window fails.
  evf:  assert property (@(posedge clk) eventually [1:2] z)   else f_evfail++;

  initial begin
    repeat (10) @(posedge clk);
    if (f_alw  != 0) begin $display("FAIL always got=%0d exp=0", f_alw); errors++; end
    if (f_balw != 0) begin $display("FAIL always[1:3] got=%0d exp=0", f_balw); errors++; end
    if (f_salw != 0) begin $display("FAIL s_always[1:3] got=%0d exp=0", f_salw); errors++; end
    if (f_ev   != 0) begin $display("FAIL eventually[0:3] got=%0d exp=0", f_ev); errors++; end
    if (f_sev  != 0) begin $display("FAIL s_eventually[1:3] got=%0d exp=0", f_sev); errors++; end
    if (f_evfail == 0) begin $display("FAIL eventually[1:2] z never fired"); errors++; end
    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
