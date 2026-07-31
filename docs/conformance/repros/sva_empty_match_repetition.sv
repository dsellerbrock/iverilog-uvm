// Reproducer: consecutive repetition with a lower bound of ZERO -- the
// EMPTY match of IEEE 1800-2017 16.9.2 -- is rejected, and the
// assertion is DROPPED:
//
//   sorry: this repetition shape is not supported (literal bounds >= 1
//   on copyable operands only); the assertion is dropped.
//
// The boundary is exactly the zero lower bound. Measured matrix:
//
//   a[*0]     ##1 b      REJECTED
//   a[*0:2]   ##1 b      REJECTED
//   a[*0:$]   ##1 b      REJECTED
//   b |-> a[*0]          REJECTED
//   a[*1:2]   ##1 b      accepted
//   a[*1:$]   ##1 b      accepted
//   a[*2]     ##1 b      accepted
//
// So the repetition machinery itself works; only the empty match is
// missing. pform_sva_consec_repeat's validity test requires lo >= 1 and
// marks anything else delay_lo = -3, which the lowering in pform.cc
// (~13133) then reports and drops.
//
// A dropped assertion is the dangerous part: the design still compiles
// and simulates, so a verification flow silently loses the check. It is
// loud at compile time, but nothing at run time says the property is
// not being evaluated.
//
// What 16.9.2.1 requires, for the concatenation cases:
//
//   (empty ##0 seq) = seq          (seq ##0 empty) = seq
//   (empty ##1 seq) = seq          (seq ##1 empty) = seq
//   (empty ##n seq) = ##(n-1) seq  for n > 1
//
// A bounded `a[*0:n] ##1 b' is therefore a finite UNION of concrete
// alternatives -- b, (a ##1 b), (a ##1 a ##1 b), ... -- which the
// automaton engine can already express: the C5 window/union machinery
// (nfa_product_fragment_, the per-arrival fragments) builds exactly
// this shape. The unbounded `a[*0:$]' is `b or (a[*1:$] ##1 b)', and
// a[*1:$] is already supported.
//
// The legacy linear engine (IVL_SVA_LEGACY=1) has no union construct,
// so it must keep rejecting these loudly -- which makes this an
// nfa-only test in tests/sva_nfa/, with a .gold for the automaton run.
//
// Next step for this item: expand a zero-lower-bound repetition into
// that union at pform level, where the existing bounded repetition is
// already validated, rather than teaching the step representation about
// an empty match.
module top;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  // Should reduce to plain `b' (16.9.2.1) and hold when b is high.
  ap_empty:  assert property (@(posedge clk) a[*0] ##1 b);

  // Should be the union of b, (a ##1 b), (a ##1 a ##1 b).
  ap_range:  assert property (@(posedge clk) a[*0:2] ##1 b);

  // Controls: these already work, and must keep working.
  ap_one:    assert property (@(posedge clk) a[*1:2] |-> ##1 1'b1);
  ap_unb:    assert property (@(posedge clk) a[*1:$] |-> ##1 1'b1);

  initial begin
    @(posedge clk); b <= 1;
    repeat (4) @(posedge clk);
    $display("DONE");
    $finish;
  end
endmodule
