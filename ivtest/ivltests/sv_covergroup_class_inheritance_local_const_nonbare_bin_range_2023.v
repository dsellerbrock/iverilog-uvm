class base_c;
  bit [3:0] v;
  local const int k = 2;
  covergroup cg;
    cp: coverpoint v { bins b = {k + 1}; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  derived_c d;
  real c;
  initial begin
    d = new;
    d.v = 3;
    d.cg.sample();
    c = d.cg.get_inst_coverage();
    if (c != 100.0) $fatal(1, "base local const range not sampled: %0.1f", c);
    $display("PASSED");
  end
endmodule
