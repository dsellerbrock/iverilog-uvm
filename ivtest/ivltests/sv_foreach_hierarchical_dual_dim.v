// IEEE 1800-2017 11.7 extended to a hierarchical target:
// `foreach (a[k1,...].b[i1,...])' declares NEW loop variables for
// EACH bracket group and iterates every combination -- there is no
// standard "fixed outer index, loop the inner dimension" reading for
// a bare identifier in the outer bracket (that shape needs a genuine
// expression, e.g. `a[k+0].b[i]`, to disambiguate from a loop-variable
// declaration).
//
// This construct used to be a parser stub: the grammar action built
// no PForeach node at all and unconditionally discarded the loop
// body, with no diagnostic in the common case (the only guard,
// pform_requires_sv(), is a silent no-op once SystemVerilog mode is
// active, which it is for virtually all real input) -- a fully silent
// zero-iteration bug. Reduced from OpenTitan xbar_env_pkg.sv's
// `foreach (xbar_devices[i].addr_ranges[j])`.
typedef struct { int v[3]; } holder_t;

module main;
  holder_t h[2];
  int errors = 0;
  int seen[2][3];

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    h[0].v = '{5, 9, 20};
    h[1].v = '{1, 2, 3};

    foreach (h[k].v[i]) begin
      seen[k][i] = h[k].v[i];
    end

    check("h[0].v[0]", seen[0][0], 5);
    check("h[0].v[1]", seen[0][1], 9);
    check("h[0].v[2]", seen[0][2], 20);
    check("h[1].v[0]", seen[1][0], 1);
    check("h[1].v[1]", seen[1][1], 2);
    check("h[1].v[2]", seen[1][2], 3);

    // A loop variable name that shadows an already-declared outer
    // variable of the same name is standard-compliant (the loop
    // variable is a fresh local, IEEE 1800-2017 11.7) -- confirm the
    // shadowing itself does not crash or misbehave, without asserting
    // anything about the (unrelated) outer variable's own value.
    begin
      int k;
      k = 77;
      foreach (h[k].v[i]) begin
        seen[k][i] = h[k].v[i];
      end
      check("outer k unaffected by loop-var shadow", k, 77);
    end

    if (errors == 0) $display("PASSED");
    else $display("%0d checks failed", errors);
  end
endmodule
