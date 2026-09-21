module sv_covergroup_cross_with_value_limit;
  int a, b;
  covergroup cg;
    ca: coverpoint a { bins all = {[0:255]}; }
    cb: coverpoint b { bins all = {[0:255]}; }
    cx: cross ca, cb {
      // Exactly 65,536 value tuples: accepted boundary. The false predicate
      // forces evaluation of all of them instead of succeeding early.
      ignore_bins never = (binsof(ca) && binsof(cb)) with (ca < 0);
    }
  endgroup
  cg cov = new;
  initial begin
    if (cov.get_inst_coverage() != 0.0) $fatal(1, "initial coverage");
    a = 255; b = 255; cov.sample();
    if (cov.get_inst_coverage() != 100.0) $fatal(1, "retained bin missing");
    $display("PASSED");
    $finish;
  end
endmodule
