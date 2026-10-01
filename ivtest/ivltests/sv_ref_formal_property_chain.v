// A `ref' formal bound to a property of a handle reached through other
// properties (`m.cfg.start') names that storage for the whole call (IEEE
// 1800-2017/2023 13.5.2): a write through the formal is seen by every other
// process at once, not only at the return. Task calls copied such an actual
// through a temporary (OpenTitan i2c monitor: `perf_monitor(cfg.start, ...)').
class ev; int v = 1; endclass
class cfgc;
  ev start;
  int unsigned n;
endclass

class mon;
  cfgc cfg;
  task automatic perf(ref ev s, ref int unsigned n);
    s = null;
    n = 41;
    #5;
    n = n + 1;
  endtask
  task run();
    perf(cfg.start, cfg.n);
  endtask

  // The same through a function call: the callee sees its own write by name.
  function bit f(ref int unsigned n);
    n = 77;
    return cfg.n == 77;
  endfunction
  function bit call_f();
    return f(cfg.n);
  endfunction
endclass

module main;
  int errors;
  initial begin
    mon m;
    m = new; m.cfg = new; m.cfg.start = new; m.cfg.n = 1;
    fork
      m.run();
      begin
        #2;
        if (m.cfg.start !== null || m.cfg.n !== 41) begin
          $display("FAILED during the call: start null=%0d n=%0d",
                   m.cfg.start == null, m.cfg.n);
          errors++;
        end
      end
    join
    if (m.cfg.start !== null || m.cfg.n !== 42) begin
      $display("FAILED after the call: n=%0d", m.cfg.n); errors++;
    end
    if (!m.call_f()) begin $display("FAILED function alias"); errors++; end
    if (errors == 0) $display("PASSED");
  end
endmodule
