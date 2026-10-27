// IEEE 1800-2017/2023 19.5: an unlabeled single-variable coverpoint
// uses the variable name as its coverage-point name.
module sv_covergroup_implicit_cp_name;
  bit [1:0] v;

  covergroup cg;
    coverpoint v { bins b[] = {[0:3]}; }
  endgroup

  cg g = new;

  initial begin
    v = 1;
    g.sample();
    if (g.v.get_inst_coverage() > 24.9
        && g.v.get_inst_coverage() < 25.1)
      $display("PASSED");
    else
      $display("FAILED: implicit coverpoint coverage is %f",
               g.v.get_inst_coverage());
    $finish;
  end
endmodule
