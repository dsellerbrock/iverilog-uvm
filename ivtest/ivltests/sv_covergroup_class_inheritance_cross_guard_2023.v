class cross_base;
  bit a, g;
  covergroup cg;
    cp_a: coverpoint a { bins z = {0}; }
    cp_g: coverpoint g { bins z = {0}; bins o = {1}; }
    x: cross cp_a, cp_g iff (g);
  endgroup
  function new; cg = new; endfunction
  function void go; cg.sample(); endfunction
endclass

class cross_derived extends cross_base;
  covergroup extends cg;
    x: cross cp_a, cp_g;
  endgroup : cg
endclass

module test;
  cross_derived cross_from_base, cross_direct;
  cross_base base_view, control;
  real control_coverage, cross_base_coverage, cross_direct_coverage;

  initial begin
    cross_from_base = new;
    cross_from_base.a = 0;
    cross_from_base.g = 0;
    base_view = cross_from_base;
    base_view.go();
    cross_base_coverage = cross_from_base.cg.get_inst_coverage();

    cross_direct = new;
    cross_direct.a = 0;
    cross_direct.g = 0;
    cross_direct.cg.sample();
    cross_direct_coverage = cross_direct.cg.get_inst_coverage();

    control = new;
    control.a = 0;
    control.g = 0;
    control.go();
    control_coverage = control.cg.get_inst_coverage();

    $display("control=%0.1f derived_handle=%0.1f base_method=%0.1f",
             control_coverage, cross_direct_coverage, cross_base_coverage);
    if (control_coverage < 49.9 || control_coverage > 50.1
        || cross_direct_coverage < 66.6 || cross_direct_coverage > 66.7
        || cross_base_coverage < 66.6 || cross_base_coverage > 66.7) begin
      $display("FAILED cross control=%0.1f derived=%0.1f base-method=%0.1f",
               control_coverage, cross_direct_coverage, cross_base_coverage);
      $fatal(1);
    end
    $display("PASSED");
  end
endmodule
