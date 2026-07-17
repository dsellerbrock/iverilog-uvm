// M3-rm: per-field rand_mode(0) (IEEE 1800-2017 18.8). `obj.field.rand_mode(0)`
// must freeze ONLY that field's randomization; previously it was a silent
// no-op and the "frozen" field was still randomized (a silent miscompile
// that could produce illegal stimulus). Object-level obj.rand_mode(0)
// (freeze all) must still work.
//
// Adversarial: verify (1) the frozen field never changes across many
// randomize() calls, (2) a sibling rand field DOES change, (3) re-enabling
// with rand_mode(1) restores randomization, (4) object-level freeze still
// freezes every field.
module m3rm_rand_mode_field_test_top;
  class P;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand bit [7:0] c;
  endclass

  int errors = 0;
  task ck(string w, int got, int exp);
    if (got !== exp) begin $display("FAIL: %s got=%0d exp=%0d", w, got, exp); errors++; end
  endtask

  initial begin
    P p = new;
    int a_changed = 0, c_changed = 0, b_frozen = 1;

    p.a = 8'd44; p.b = 8'd77; p.c = 8'd11;
    p.b.rand_mode(0);              // freeze ONLY b

    repeat (40) begin
      void'(p.randomize());
      if (p.a != 8'd44) a_changed = 1;
      if (p.c != 8'd11) c_changed = 1;
      if (p.b != 8'd77) b_frozen  = 0;   // b must never change
    end
    ck("frozen b unchanged", b_frozen, 1);
    ck("frozen b value", p.b, 8'd77);
    ck("sibling a randomized", a_changed, 1);
    ck("sibling c randomized", c_changed, 1);

    // Re-enable b -> it must randomize again.
    p.b.rand_mode(1);
    begin
      int b_changed_now = 0;
      repeat (40) begin void'(p.randomize()); if (p.b != 8'd77) b_changed_now = 1; end
      ck("re-enabled b randomizes", b_changed_now, 1);
    end

    // Object-level freeze: all fields held.
    begin
      P q = new;
      int any_changed = 0;
      q.a = 8'd1; q.b = 8'd2; q.c = 8'd3;
      q.rand_mode(0);              // freeze ALL
      repeat (40) begin
        void'(q.randomize());
        if (q.a != 8'd1 || q.b != 8'd2 || q.c != 8'd3) any_changed = 1;
      end
      ck("object-level freeze holds all", any_changed, 0);
    end

    if (errors == 0) $display("PASS: m3rm per-field rand_mode");
    else $display("FAIL: m3rm per-field rand_mode (%0d errors)", errors);
    $finish(0);
  end
endmodule
