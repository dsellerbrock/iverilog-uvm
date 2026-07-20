// Bounded `nexttime[n]' / `s_nexttime[n]' (IEEE 1800-2017 16.12.2): p must
// hold n cycles after each attempt (n==1 is the plain form). This is a
// source-level lowering in pform.cc — the op-9/10 $past validity guard
// uses offset n instead of 1 — so BOTH engines lower it identically and
// this is an ordinary dual-run parity test.
//
// NFA-EXPECT-FALLBACK: a unary liveness operator over a boolean is a pform
// source rewrite; the sequence automaton never engages, so both runs use
// the same lowering and their verdict streams must match exactly.
//
// p is 1 at every posedge from cycle 1 on, EXCEPT cycle 3 where it is 0.
//   nexttime[2] p : attempt at cycle 1 requires p@3 == 0  -> one FAIL@t.
//   nexttime[1] p : attempt at cycle 2 requires p@3 == 0  -> one FAIL@t.
module bounded_nexttime_t;
  logic clk=0;
  reg   p=0;
  integer cyc=0;
  always #5 clk = ~clk;

  // Drive p on negedge so the posedge sample is stable: p=1 from cyc1 on,
  // but p=0 exactly at cyc3.
  always @(negedge clk) begin
    cyc = cyc + 1;
    p = (cyc >= 1) && (cyc != 3);
  end

  n2: assert property (@(posedge clk) nexttime[2] p)
        else $display("NT2_FAIL@%0t", $time);
  n1: assert property (@(posedge clk) nexttime[1] p)
        else $display("NT1_FAIL@%0t", $time);

  initial begin
    repeat (8) @(negedge clk);
    $display("done cyc=%0d", cyc);
    $finish(0);
  end
endmodule
