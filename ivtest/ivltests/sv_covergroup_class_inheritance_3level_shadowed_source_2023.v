class base_c;
  bit a;
  covergroup cg;
    cp_base: coverpoint a { bins one = {1}; }
  endgroup
  function new; cg = new; endfunction
endclass

class middle_c extends base_c;
  bit a;
  covergroup extends cg;
    cp_middle: coverpoint a { bins zero = {0}; }
  endgroup : cg
endclass

class derived_c extends middle_c;
  bit e;
  covergroup extends cg;
    cp_derived: coverpoint e { bins on = {1}; }
  endgroup : cg
endclass

class shadowed_c extends middle_c;
  bit a;
  bit e;
  covergroup extends cg;
    cp_shadowed: coverpoint e { bins on = {1}; }
  endgroup : cg
endclass

module test;
  base_c base_view;
  middle_c middle_view;
  derived_c direct, via_middle, via_base;
  shadowed_c shadow_direct, shadow_via_middle, shadow_via_base;
  real coverage;

  initial begin
    direct = new;
    direct.e = 1;
    middle_view = direct;
    middle_view.a = 0;
    base_view = direct;
    base_view.a = 1;
    direct.cg.sample();
    coverage = direct.cg.get_inst_coverage();
    if (coverage != 100.0) $fatal(1, "direct handle: %0.1f", coverage);

    via_middle = new;
    via_middle.e = 1;
    middle_view = via_middle;
    middle_view.a = 0;
    base_view = via_middle;
    base_view.a = 1;
    middle_view.cg.sample();
    coverage = via_middle.cg.get_inst_coverage();
    if (coverage != 100.0) $fatal(1, "middle handle: %0.1f", coverage);

    via_base = new;
    via_base.e = 1;
    middle_view = via_base;
    middle_view.a = 0;
    base_view = via_base;
    base_view.a = 1;
    base_view.cg.sample();
    coverage = via_base.cg.get_inst_coverage();
    if (coverage != 100.0) $fatal(1, "base handle: %0.1f", coverage);

    shadow_direct = new;
    shadow_direct.a = 0;
    shadow_direct.e = 1;
    middle_view = shadow_direct;
    middle_view.a = 0;
    base_view = shadow_direct;
    base_view.a = 1;
    shadow_direct.cg.sample();
    coverage = shadow_direct.cg.get_inst_coverage();
    if (coverage != 100.0) $fatal(1, "shadow direct handle: %0.1f", coverage);

    shadow_via_middle = new;
    shadow_via_middle.a = 0;
    shadow_via_middle.e = 1;
    middle_view = shadow_via_middle;
    middle_view.a = 0;
    base_view = shadow_via_middle;
    base_view.a = 1;
    middle_view.cg.sample();
    coverage = shadow_via_middle.cg.get_inst_coverage();
    if (coverage != 100.0) $fatal(1, "shadow middle handle: %0.1f", coverage);

    shadow_via_base = new;
    shadow_via_base.a = 0;
    shadow_via_base.e = 1;
    middle_view = shadow_via_base;
    middle_view.a = 0;
    base_view = shadow_via_base;
    base_view.a = 1;
    base_view.cg.sample();
    coverage = shadow_via_base.cg.get_inst_coverage();
    if (coverage != 100.0) $fatal(1, "shadow base handle: %0.1f", coverage);

    $display("PASSED");
  end
endmodule
