class base_c;
  bit a;
  bit x;
  covergroup cg;
    cp_x: coverpoint x { bins hit = {1} iff (a); }
  endgroup
  function new; cg = new; endfunction
endclass

class derived_c extends base_c;
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  derived_c d;
  initial begin
    d = new;
    d.x = 1;
    d.a = 0;
    d.cg.sample();
    if (d.cg.get_inst_coverage() != 0.0) begin
      $display("FAILED disabled=%0.1f", d.cg.get_inst_coverage());
      $fatal(1);
    end
    d.a = 1;
    d.cg.sample();
    if (d.cg.get_inst_coverage() != 100.0) begin
      $display("FAILED enabled=%0.1f", d.cg.get_inst_coverage());
      $fatal(1);
    end
    $display("PASSED");
  end
endmodule
