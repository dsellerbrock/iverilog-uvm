class base_c;
  bit a, b;
  covergroup cg;
    x: cross a, b;
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  bit e;
  covergroup extends cg;
    y: cross a, e;
  endgroup : cg
endclass

class flat_c;
  bit a, b, e;
  covergroup cg;
    x: cross a, b;
    y: cross a, e;
  endgroup
  function new; cg = new; endfunction
endclass

module test;
  derived_c through_base, direct;
  base_c base_view;
  flat_c flat_base, flat_direct;
  real base_coverage, flat_base_coverage;
  real direct_coverage, flat_direct_coverage;

  initial begin
    through_base = new;
    base_view = through_base;
    flat_base = new;
    through_base.a = 0; through_base.b = 0; through_base.e = 0;
    flat_base.a = 0; flat_base.b = 0; flat_base.e = 0;
    base_view.cg.sample(); flat_base.cg.sample();
    through_base.a = 1; through_base.b = 1; through_base.e = 1;
    flat_base.a = 1; flat_base.b = 1; flat_base.e = 1;
    base_view.cg.sample(); flat_base.cg.sample();
    base_coverage = through_base.cg.get_inst_coverage();
    flat_base_coverage = flat_base.cg.get_inst_coverage();

    direct = new;
    flat_direct = new;
    direct.a = 0; direct.b = 0; direct.e = 0;
    flat_direct.a = 0; flat_direct.b = 0; flat_direct.e = 0;
    direct.cg.sample(); flat_direct.cg.sample();
    direct.a = 1; direct.b = 1; direct.e = 1;
    flat_direct.a = 1; flat_direct.b = 1; flat_direct.e = 1;
    direct.cg.sample(); flat_direct.cg.sample();
    direct_coverage = direct.cg.get_inst_coverage();
    flat_direct_coverage = flat_direct.cg.get_inst_coverage();

    if (base_coverage != flat_base_coverage
        || direct_coverage != flat_direct_coverage)
      $fatal(1, "implicit cross differs from flat equivalent");
    $display("PASS implicit cross: base=%0.3f flat=%0.3f direct=%0.3f flat-direct=%0.3f",
             base_coverage, flat_base_coverage,
             direct_coverage, flat_direct_coverage);
  end
endmodule
