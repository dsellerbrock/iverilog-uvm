class base_c;
  bit [3:0] v;
  local const int k = 2;
  covergroup cg;
    cp: coverpoint v { bins b = {k}; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  derived_c direct, through_base;
  base_c b;
  real c;
  initial begin
    direct = new;
    direct.v = 2;
    direct.cg.sample();
    c = direct.cg.get_inst_coverage();
    if (c != 100.0) begin
      $display("FAILED direct=%0.1f", c);
      $fatal(1);
    end
    through_base = new;
    through_base.v = 2;
    b = through_base;
    b.cg.sample();
    c = through_base.cg.get_inst_coverage();
    if (c != 100.0) begin
      $display("FAILED base=%0.1f", c);
      $fatal(1);
    end
    $display("PASSED");
  end
endmodule
