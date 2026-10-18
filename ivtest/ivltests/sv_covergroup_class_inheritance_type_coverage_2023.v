class B; bit a;
  covergroup cg;
    cp: coverpoint a { bins z = {0}; bins o = {1}; }
  endgroup
  function new; cg = new; endfunction
endclass
class D extends B;
  covergroup extends cg;
  endgroup : cg
endclass
module t; B bo = new; D dobj = new; B bv; real tb, td, tv;
  initial begin
    bo.a = 0; bo.cg.sample();
    dobj.a = 1; dobj.cg.sample();
    bv = dobj;
    tb = bo.cg.get_coverage();
    td = dobj.cg.get_coverage();
    tv = bv.cg.get_coverage();
    $display("tb=%0.1f td=%0.1f tv=%0.1f", tb, td, tv);
    if (tb != 50.0 || td != 50.0 || tv != 50.0) $fatal(1, "type coverage merged");
    $display("PASS type coverage remains separate");
    $display("PASSED");
  end
endmodule
