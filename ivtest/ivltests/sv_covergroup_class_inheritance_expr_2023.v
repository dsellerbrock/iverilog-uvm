class base_c;
  bit a;
  covergroup cg;
    option.per_instance = 1;
    cp_base: coverpoint a { bins zero = {0}; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  bit d;
  covergroup extends cg;
    cp_expr: coverpoint d + 1 { bins two = {2}; }
  endgroup : cg
endclass

module test;
  derived_c derived;
  base_c base_view;
  real coverage;
  initial begin
    derived = new;
    derived.a = 0;
    derived.d = 1;
    base_view = derived;
    base_view.cg.sample();
    coverage = derived.cg.get_inst_coverage();
    if (coverage < 99.9 || coverage > 100.1)
      $fatal(1, "derived coverpoint expression was not sampled: %f", coverage);
    $display("PASSED");
  end
endmodule
