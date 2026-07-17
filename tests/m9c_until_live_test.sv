// M9C: strong `until` liveness (IEEE 1800-2017 16.12.10). `p s_until q`
// additionally requires q to eventually hold. With p held high and q
// never asserting, the WEAK per-cycle check never fires (p is always 1),
// but the strong liveness obligation is outstanding at end of simulation
// and must report a failure (a $error from the synthesized FINAL block,
// shown after the PASS line below).
//
// The machine-checked part is the contrast: the weak operator and the
// strong operator's per-cycle path both stay silent here, isolating the
// failure to the liveness obligation alone.
module m9c_until_live_test_top;
  logic clk = 0, p = 1, q = 0;
  int f_u = 0, f_su = 0;
  always #5 clk = ~clk;

  u:  assert property (@(posedge clk) p until   q) else f_u++;
  su: assert property (@(posedge clk) p s_until q) else f_su++;

  initial begin
    repeat (6) begin p = 1; q = 0; @(posedge clk); #1; end
    if (f_u !== 0)
      $display("FAIL: weak until fired unexpectedly (%0d)", f_u);
    else if (f_su !== 0)
      $display("FAIL: strong until per-cycle fired unexpectedly (%0d)", f_su);
    else
      $display("PASS: m9c until liveness (strong liveness $error expected next)");
    $finish(0);
  end
endmodule
