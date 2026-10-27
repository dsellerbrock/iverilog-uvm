// IEEE 1800-2017/2023 §§19.6 and 19.6.1: explicit/implicit crosses,
// cross iff, user bins, and retention of unselected automatic cross bins.
module test;
  int fails = 0;
  task automatic check(string id, bit ok);
    if (ok) $display("PASS %s", id);
    else begin $display("FAIL %s", id); fails++; end
  endtask
  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  covergroup cross_cg with function sample(bit a, bit b, bit en);
    cp_a: coverpoint a { bins a0 = {0}; bins a1 = {1}; }
    cp_b: coverpoint b { bins b0 = {0}; bins b1 = {1}; }
    explicit_cross: cross cp_a, cp_b;
    implicit_cross: cross cp_a, b iff (en);
    user_cross: cross cp_a, cp_b {
      bins zero_zero = binsof(cp_a.a0) && binsof(cp_b.b0);
      bins zero_one = binsof(cp_a.a0) && binsof(cp_b.b1);
    }
  endgroup

  covergroup guard_cg with function sample(bit a, bit b, bit en);
    cp_a: coverpoint a { bins a0 = {0}; bins a1 = {1}; }
    cp_b: coverpoint b { bins b0 = {0}; bins b1 = {1}; }
    guarded_cross: cross cp_a, cp_b iff (en);
  endgroup

  cross_cg cov = new;
  guard_cg guard_cov = new;
  initial begin
    cov.sample(0, 0, 0);
    guard_cov.sample(0, 0, 0);
    check("explicit cross first product", near(cov.explicit_cross.get_inst_coverage(), 25.0));
    check("implicit variable cross iff false", cov.implicit_cross.get_inst_coverage() == 0.0);
    check("user bin first product", near(cov.user_cross.get_inst_coverage(), 25.0));
    check("false iff still samples coverpoints",
          guard_cov.cp_a.get_inst_coverage() == 50.0 &&
          guard_cov.cp_b.get_inst_coverage() == 50.0 &&
          guard_cov.guarded_cross.get_inst_coverage() == 0.0);

    cov.sample(0, 1, 1);
    cov.sample(1, 1, 1);
    cov.sample(1, 0, 1);
    check("explicit cross all products", cov.explicit_cross.get_inst_coverage() == 100.0);
    check("implicit variable cross all products", cov.implicit_cross.get_inst_coverage() == 100.0);
    check("user bins retain automatic products", cov.user_cross.get_inst_coverage() == 100.0);

    if (fails == 0) $display("PASS 19.6 cross coverage");
    else $fatal(1, "%0d cross coverage checks failed", fails);
    $finish;
  end
endmodule
