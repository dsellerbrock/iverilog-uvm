// Blast-radius guard for the new PETernary type-context elaboration.
//
// This test does NOT discriminate against the pre-fix compiler -- it
// passes on both, and that is the point. Before the change, a
// conditional in a class/queue/string/dynamic-array context reached
// PExpr's default type-context handler, which forwarded to the WIDTH
// form with a width of 1. Those contexts now run through
// PETernary::elaborate_expr(ivl_type_t), code that previously never
// executed for them. This pins the behaviour that must not change.
//
// The discriminating test for the fix itself is
// sv_ternary_pattern_type_ctx.v.
module sv_ternary_typed_aggregates;

  class C;
    int x;
    function new(int v); x = v; endfunction
  endclass

  C      a, b, r;
  int    q1[$], q2[$], qr[$];
  string s1 = "aa", s2 = "bb", sr;
  int    da1[], da2[], dar[];
  bit    sel;
  int    errors = 0;

  initial begin
    a = new(7); b = new(9);
    q1 = '{1,2,3}; q2 = '{4,5};
    da1 = new[2]; da1[0] = 8; da1[1] = 9;
    da2 = new[1]; da2[0] = 3;

    sel = 1; r = sel ? a : b;
    if (r.x !== 7) begin $display("FAIL class-true %0d", r.x); errors++; end
    sel = 0; r = sel ? a : b;
    if (r.x !== 9) begin $display("FAIL class-false %0d", r.x); errors++; end

    sel = 1; qr = sel ? q1 : q2;
    if (qr.size() !== 3 || qr[2] !== 3) begin $display("FAIL queue-true"); errors++; end
    sel = 0; qr = sel ? q1 : q2;
    if (qr.size() !== 2 || qr[1] !== 5) begin $display("FAIL queue-false"); errors++; end

    sel = 1; sr = sel ? s1 : s2;
    if (sr != "aa") begin $display("FAIL string-true %0s", sr); errors++; end
    sel = 0; sr = sel ? s1 : s2;
    if (sr != "bb") begin $display("FAIL string-false %0s", sr); errors++; end

    sel = 1; dar = sel ? da1 : da2;
    if (dar.size() !== 2 || dar[1] !== 9) begin $display("FAIL darray-true"); errors++; end
    sel = 0; dar = sel ? da1 : da2;
    if (dar.size() !== 1 || dar[0] !== 3) begin $display("FAIL darray-false"); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule
