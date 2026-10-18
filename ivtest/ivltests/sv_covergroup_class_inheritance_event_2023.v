`timescale 1ns/1ns
module test;
  bit clk = 0;
  class B;
    bit a;
    covergroup cg @(posedge clk);
      option.at_least = 2;
      cp_a: coverpoint a { bins z = {0}; bins o = {1}; }
    endgroup
    function new; cg = new; endfunction
  endclass
  class D extends B;
    bit d;
    covergroup extends cg;
      cp_d: coverpoint d { bins z = {0}; bins o = {1}; }
    endgroup : cg
  endclass
  B bo = new;
  D dobj = new;
  real cb, cd;
  initial begin
    bo.a = 0;
    dobj.a = 0;
    dobj.d = 0;
    #1 clk = 1;
    #1;
    cb = bo.cg.get_inst_coverage();
    cd = dobj.cg.get_inst_coverage();
    $display("edge1 b=%0.1f d=%0.1f", cb, cd);
    if (cb != 0.0 || cd != 0.0)
      $fatal(1, "one edge must not satisfy at_least=2");
    #1 clk = 0;
    #1 clk = 1;
    #1;
    cb = bo.cg.get_inst_coverage();
    cd = dobj.cg.get_inst_coverage();
    $display("edge2 b=%0.1f d=%0.1f", cb, cd);
    if (cb != 50.0 || cd != 50.0)
      $fatal(1, "two edges must sample each inherited group exactly once");
    $display("PASSED");
  end
endmodule
