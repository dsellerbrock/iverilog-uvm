// A completely action-less `assert/assume property (p);' on a liveness
// operator (bare `;', no pass action and no `else' arm at all) must
// compile clean -- there is no pass action to refuse. IEEE 1800-2017
// A.2.10's "pass action only" concurrent_assertion_statement production
// admits an empty statement_or_null for the trailing statement; that
// carries the identical PNoop "no action" sentinel used by the
// `else ;' and `cover property (p);' forms, and must be recognized as
// such regardless of assert/assume/cover.
//
// Before this fix, pform_make_assertion() only consumed that sentinel
// for `cover' (kind==2); for assert/assume it flowed through unconsumed
// and pform_make_temporal_assertion_() saw it as a genuine non-null
// pass action, wrongly refusing the statement with "a pass action on
// this property operator is not supported" even though the source wrote
// no action whatsoever. Real, unmodified Caliptra/Adams-Bridge formal
// verification sources (e.g.
// formal/fv_ntt_ctrl/fv_ntt_ctrl_constraints.sv) use exactly this shape:
// `assume_x: assume property ( s_eventually(sig) );'.
module main;
  bit clk = 0;
  bit x = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  // Bare pass-action-only form, empty statement (a lone `;') -- must not
  // be refused. Both assert and assume, and both a plain liveness
  // operator and an implication with a liveness consequent (a
  // structurally different op_type in the same "temporal family" that
  // reaches the same lowering).
  ap_bare: assert property (s_eventually(x));
  am_bare: assume property (s_eventually(x));
  ap_impl_bare: assert property (1'b1 |-> s_eventually(x));

  // Sibling forms (a real pass action still correctly refused,
  // `else'-only unaffected, `cover property' unaffected since it already
  // consumed the sentinel before this fix) are covered by the negative
  // and existing ivtest reducers built during investigation, not
  // repeated here to keep this a focused positive regression.

  initial begin
    x = 1;
    #20;
    $display("PASSED");
    $finish;
  end
endmodule
