// Covergroups `with function sample(<formals>)` (IEEE 1800-2017
// 19.8.1) — the formal names bind positionally (or by name) to the
// sample() call arguments at each call site, at module, package, and
// class scope. A formal shadows a scope signal or parent-class
// property of the same name. Previously the module form was a parse
// error and the package form was a silent stub (no coverage).
package wfs_pkg;
  covergroup pcg with function sample(bit [1:0] v);
    cp_v: coverpoint v { bins b[] = {0,1,2,3}; }
  endgroup
endpackage

module main;
  import wfs_pkg::*;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  bit [1:0] m = 3;      // scope signal shadowed by the formal below
  bit scope_sig = 1;

  // formals as sources, iff guard on a formal, plus a scope signal mix
  covergroup cg with function sample(bit [1:0] m, bit en);
    cp_m: coverpoint m iff (en) { bins b[] = {0,1,2,3}; }
    cp_s: coverpoint scope_sig { bins s1 = {1}; bins s0 = {0}; }
  endgroup

  // cross over formal coverpoints
  covergroup xg with function sample(bit a, bit b);
    cp_a: coverpoint a { bins v[] = {0,1}; }
    cp_b: coverpoint b { bins v[] = {0,1}; }
    axb: cross cp_a, cp_b;
  endgroup

  // class-embedded form: formal p shadows property p; sampled both
  // from inside the class and via a chained module-scope call
  class C;
    bit [1:0] p;
    covergroup cov with function sample(bit [1:0] q, bit [1:0] p);
      cp_q: coverpoint q { bins b[] = {0,1,2,3}; }
      cp_p: coverpoint p { bins b[] = {0,1,2,3}; }
    endgroup
    function new; cov = new; p = 0; endfunction
    function void go; cov.sample(2, 3); endfunction
  endclass

  cg c1 = new;
  cg c2 = new;
  xg x1 = new;
  pcg p1 = new;
  C  h  = new;

  initial begin
    c1.sample(0, 1);
    c1.sample(1, 1);
    c1.sample(2, 0);    // en=0: guarded off, 2 must not count
    // cp_m 2/4, cp_s 1/2 -> 50.0 ; c2 untouched -> 0.0
    check("formal sources + iff", c1.get_inst_coverage() == 50.0);
    check("per-instance", c2.get_inst_coverage() == 0.0);
    check("scope m untouched", m == 3);

    x1.sample(0, 0);
    x1.sample(1, 1);
    // cp_a 2/2, cp_b 2/2, cross 2/4 -> (100+100+50)/3
    check("cross of formals", x1.get_inst_coverage() > 83.3 &&
                              x1.get_inst_coverage() < 83.4);

    p1.sample(2);        // positional
    p1.sample(.v(3));    // named
    check("package + named arg", p1.get_inst_coverage() == 50.0);

    h.go();              // q=2, formal p=3 (property p stays 0)
    h.cov.sample(3, 1);  // chained: q=3, p=1
    // cp_q bins 2,3 -> 50 ; cp_p bins 3,1 -> 50
    check("class-embedded + shadowing", h.cov.get_inst_coverage() == 50.0);
    check("property p untouched", h.p == 0);

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule
