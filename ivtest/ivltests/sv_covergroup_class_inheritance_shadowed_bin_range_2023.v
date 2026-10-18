class base_c;
  bit [3:0] v;
  local const int k = 2;
  covergroup cg;
    cp: coverpoint v { bins b = {k}; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  const int k = 1;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  derived_c d;
  real c;
  initial begin
    d = new;
    d.v = 2;
    d.cg.sample();
    c = d.cg.get_inst_coverage();
    if (c != 100.0) begin
      $display("FAILED c=%0.1f", c);
      $fatal(1);
    end
    $display("PASSED");
  end
endmodule
