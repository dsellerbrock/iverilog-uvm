// IEEE 1800-2017/2023 6.21: static locals allow hierarchical references.
class counter;
  function int visit();
    static int count = 0;
    static chandle handle;
    return ++count;
  endfunction
  function int read_count(); return visit.count; endfunction
  function void reset_count(); visit.count = 0; visit.handle = null; endfunction
endclass
module sv_hier_static_local;
  counter a, b;
  function automatic int step();
    static int count = 4;
    begin : inner
      static int count = 10;
      count++;
    end
    return ++count;
  endfunction
  initial begin
    a = new; b = new;
    if (a.read_count() !== 0 || step.count !== 4 || step.inner.count !== 10)
      $fatal(1, "static initialization before call");
    if (a.visit() !== 1 || b.read_count() !== 1 || b.visit() !== 2)
      $fatal(1, "shared static local across objects");
    a.reset_count();
    if (b.visit() !== 1 || a.read_count() !== 1) $fatal(1, "static local write");
    if (step() !== 5 || step.inner.count !== 11) $fatal(1, "nested static update");
    step.count = 20; step.inner.count = 30;
    if (step() !== 21 || step.inner.count !== 31) $fatal(1, "nested static write");
    $display("PASSED");
  end
endmodule
