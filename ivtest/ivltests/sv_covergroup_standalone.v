// Standalone covergroups (IEEE 1800-2017 19.3) at package and module
// scope — previously a package-scope stub (no coverage) and a
// module-scope parse error. The covergroup declares a type; `new`
// creates an instance; coverpoint sources are scope signals resolved
// at each sample site; a declaration sampling event synthesizes
// automatic `always @(ev) inst.sample();` processes per instance.
package cov_pkg;
  int seen = 0;
  covergroup pcg;
    cp: coverpoint cov_pkg::seen { bins b[] = {0,1}; }
  endgroup
endpackage

module main;
  import cov_pkg::*;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  logic clk = 0;
  logic [1:0] mode = 0;
  logic [1:0] a = 0, b = 0;
  logic en = 1;
  always #5 clk = ~clk;

  // explicit-sample covergroup with an iff guard
  covergroup mcg;
    cp_mode: coverpoint mode { bins m[] = {0,1,2,3}; }
    cp_en: coverpoint en iff (en) { bins on = {1}; }
  endgroup
  mcg m1 = new;

  // cross coverage, two instances with independent state
  covergroup xcg;
    ca: coverpoint a { bins av[] = {0,1,2,3}; }
    cb: coverpoint b { bins bv[] = {0,1,2,3}; }
    x: cross ca, cb;
  endgroup
  xcg x1 = new;
  xcg x2 = new;

  // auto-sampling on the declaration event
  covergroup ecg @(posedge clk);
    cp_m: coverpoint mode { bins m[] = {0,1,2,3}; }
  endgroup
  ecg e1 = new;

  pcg p1 = new;

  initial begin
    mode = 1; m1.sample();
    mode = 2; m1.sample();
    check("module cg", m1.get_inst_coverage() == 75.0);

    a = 0; b = 0; x1.sample();
    a = 1; b = 1; x1.sample();
    a = 2; b = 2; x2.sample();
    check("cross x1", x1.get_inst_coverage() == 37.5);
    check("cross x2", x2.get_inst_coverage() == 18.75);

    seen = 0; p1.sample();
    seen = 1; p1.sample();
    check("package cg", p1.get_inst_coverage() == 100.0);

    // auto-sample: mode is 2 now; posedges at 5,15,25 see 2, 3, 0
    @(negedge clk) mode = 3;
    @(negedge clk) mode = 0;
    #12;
    check("event sampling", e1.get_inst_coverage() == 75.0);

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule
