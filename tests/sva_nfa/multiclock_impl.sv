// M9-NFA stage D.1: multiclocked non-overlapping implication
// `@(c1) a |=> @(c2) b' (IEEE 1800-2017 16.13.3). The antecedent is
// clocked by c1, the consequent by c2, and the consequent is checked at
// the first c2 tick STRICTLY AFTER the c1 tick where the antecedent held.
// Lowered by a race-free request/ack counter handoff — a dedicated
// two-domain lowering that runs regardless of IVL_SVA_NFA, so the two
// builds are identical by construction (a parity test that does NOT
// engage the NFA slot pool).
//
// NFA-EXPECT-FALLBACK
//
// c1 posedge @ 5,15,25,35 ; c2 posedge @ 10,20,30,40.
//   req@c1=5  is answered by ack@c2=10  -> pass (silent).
//   req@c1=25 has no ack before c2=30   -> FAIL@30.
module multiclock_impl_t;
  reg c1=0; always #5 c1=~c1;
  reg c2=1; always #5 c2=~c2;
  reg req=0, ack=0;

  p: assert property (@(posedge c1) req |=> @(posedge c2) ack)
       else $display("MC_FAIL@%0t", $time);

  initial begin
    #1  req=1;     // before c1@5
    #5  req=0;     // t=6
    #3  ack=1;     // t=9, before c2@10 -> discharges req@5 (pass)
    #2  ack=0;     // t=11
    #13 req=1;     // t=24, before c1@25
    #2  req=0;     // t=26 ; no ack before c2@30 -> FAIL@30
    #14 $display("mc_done");
    $finish(0);
  end
endmodule
