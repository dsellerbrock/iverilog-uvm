class base_c;
  bit a;
  covergroup cg;
    cp_a: coverpoint a { bins one = {1}; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  bit a;
  covergroup extends cg;
    cp_d: coverpoint a { bins zero = {0}; }
  endgroup : cg
endclass

module test;
  derived_c via_base, direct;
  base_c base_view;
  real via_base_coverage, direct_coverage;
  initial begin
    via_base = new;
    via_base.a = 0;
    base_view = via_base;
    base_view.a = 1;
    base_view.cg.sample();
    via_base_coverage = via_base.cg.get_inst_coverage();

    direct = new;
    direct.a = 0;
    base_view = direct;
    base_view.a = 1;
    direct.cg.sample();
    direct_coverage = direct.cg.get_inst_coverage();

    if (via_base_coverage != 100.0 || direct_coverage != 100.0) begin
      $display("FAILED inherited=%0.1f direct=%0.1f",
               via_base_coverage, direct_coverage);
      $fatal(1);
    end
    $display("PASSED");
  end
endmodule
