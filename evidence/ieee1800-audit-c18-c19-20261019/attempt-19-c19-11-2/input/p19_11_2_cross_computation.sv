// IEEE 1800-2017 §19.11.2 (p. 588) / IEEE 1800-2023 §19.11.2 (p. 616)
// Cross coverage computation: Bc = (prod Bj) - Bb, Ci = covered / (Bc + Bu),
// and zero-denominator rules.
module test;
  int fails = 0;

  task automatic check(string id, bit ok);
    if (ok) $display("PASS %s", id);
    else begin $display("FAIL %s", id); fails++; end
  endtask

  function automatic bit near(real got, real want);
    return (got > want - 0.05) && (got < want + 0.05);
  endfunction

  covergroup cg with function sample(bit a, bit b);
    cp_a: coverpoint a { bins a0 = {0}; bins a1 = {1}; }
    cp_b: coverpoint b { bins b0 = {0}; bins b1 = {1}; }

    // Auto-cross: 2 * 2 = 4 bins (Bc = 4, Bu = 0).
    x_ab: cross cp_a, cp_b;

    // Row 0 is one user bin over two products: Bc = 2, Bu = 1.
    x_user: cross cp_a, cp_b {
      bins row0 = binsof(cp_a.a0);
    }

    x_w0: cross cp_a, cp_b {
      option.weight = 0;
    }

    // Ignoring every product makes Bc + Bu zero.
    x_zero: cross cp_a, cp_b {
      ignore_bins ign = binsof(cp_a) && binsof(cp_b);
    }

    x_zero_w0: cross cp_a, cp_b {
      option.weight = 0;
      ignore_bins ign = binsof(cp_a) && binsof(cp_b);
    }
  endgroup

  initial begin
    cg g = new;
    g.sample(0, 0);
    check("auto-cross 1 of 4 bins", near(g.x_ab.get_inst_coverage(), 25.0));
    check("user-bin cross 1 of 3 bins", near(g.x_user.get_inst_coverage(), 33.333));
    check("zero-weight cross calculation", near(g.x_w0.get_inst_coverage(), 25.0));
    check("zero-denominator nonzero-weight returns 0.0",
          g.x_zero.get_inst_coverage() == 0.0);
    check("zero-denominator zero-weight returns 100.0",
          g.x_zero_w0.get_inst_coverage() == 100.0);

    g.sample(0, 1);
    check("auto-cross 2 of 4 bins", near(g.x_ab.get_inst_coverage(), 50.0));
    g.sample(1, 0);
    g.sample(1, 1);
    check("auto-cross all 4 bins", near(g.x_ab.get_inst_coverage(), 100.0));
    check("user-bin cross all 3 bins", near(g.x_user.get_inst_coverage(), 100.0));

    if (fails == 0) $display("PASS cross computation clause 19.11.2");
    else $fatal(1, "%0d cross computation checks failed", fails);
    $finish;
  end
endmodule
