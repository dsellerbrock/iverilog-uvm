class B; bit a;
  covergroup cg;
    cp: coverpoint a { bins z = {0}; bins o = {1}; }
  endgroup
  function new; cg = new; endfunction
endclass
class M extends B;
endclass
class E extends M;
  covergroup extends cg;
  endgroup : cg
endclass
module t; M mid = new; E ext = new; B base_view; real tm, te, tv;
  initial begin
    mid.a = 0; mid.cg.sample();
    ext.a = 1; ext.cg.sample();
    base_view = ext;
    tm = mid.cg.get_coverage();
    te = ext.cg.get_coverage();
    tv = base_view.cg.get_coverage();
    $display("tm=%0.1f te=%0.1f tv=%0.1f", tm, te, tv);
    if (tm != 50.0 || te != 50.0 || tv != 50.0) $fatal(1, "skip-level coverage/dispatch mismatch");
    $display("PASS skip-level inheritance coverage");
    $display("PASSED");
  end
endmodule
