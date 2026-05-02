// Phase 45 repro: virtual-interface task call (`vif.task()` where vif is a
// `virtual <iface>` class property) was being silently dropped because the
// netclass_t cached for the interface had no class_scope, so the method
// lookup at elaborate.cc:resolve_method_call_scope returned null and we
// fell into the "class scope incomplete" warn-and-noop path. Fix attaches
// the interface's NetScope as the class_scope so per-instance task/function
// children are findable, and elaborate_method_ now passes nullptr (no
// `this`) when the resolved task lives in an interface scope.

interface clk_rst_if;
  bit drive_clk;
  task automatic apply_reset();
    drive_clk = 1;
  endtask
endinterface

class cfg_t;
  virtual clk_rst_if vif;
  task call_reset();
    vif.apply_reset();
  endtask
endclass

module top;
  clk_rst_if my_if();
  cfg_t cfg;
  initial begin
    cfg = new();
    cfg.vif = my_if;
    cfg.call_reset();
    #1;
    if (my_if.drive_clk) $display("PASS");
    else $display("FAIL drive_clk=%b", my_if.drive_clk);
    $finish;
  end
endmodule
