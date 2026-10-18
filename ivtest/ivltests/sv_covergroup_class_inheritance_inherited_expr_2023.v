class base_c;
  bit [1:0] a;
  covergroup cg;
    option.per_instance = 1;
    cp: coverpoint a + 1 { bins one = {1}; bins two = {2}; }
  endgroup
  function new; cg = new; endfunction
  task go; cg.sample(); endtask
endclass

class derived_c extends base_c;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  derived_c d;
  base_c b;
  real c;
  initial begin
    d = new;
    d.a = 0;
    d.go();
    c = d.cg.get_inst_coverage();
    if (c < 49.9 || c > 50.1) $fatal(1, "first bin not sampled: %0.1f", c);
    b = d;
    d.a = 1;
    b.go();
    c = d.cg.get_inst_coverage();
    if (c < 99.9 || c > 100.1) $fatal(1, "second bin not sampled: %0.1f", c);
    $display("PASSED");
  end
endmodule
