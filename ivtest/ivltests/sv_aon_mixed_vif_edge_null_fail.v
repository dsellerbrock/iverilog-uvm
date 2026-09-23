// A null member of a mixed VIF event list must fail at the wait, even when
// another member is live; silently discarding it changes event semantics.
interface aon_mixed_null_reset_if;
  logic rst_n;
endinterface

interface aon_mixed_null_intr_if;
  logic [1:0] pins;
endinterface

class aon_mixed_null_cfg;
  virtual aon_mixed_null_reset_if rst_vif;
  virtual aon_mixed_null_intr_if intr_vif;
endclass

class aon_mixed_null_waiter;
  aon_mixed_null_cfg cfg;
  task automatic mixed();
    @(negedge cfg.rst_vif.rst_n or cfg.intr_vif.pins);
  endtask
endclass

module sv_aon_mixed_vif_edge_null_fail;
  aon_mixed_null_reset_if reset_i();
  aon_mixed_null_cfg cfg;
  aon_mixed_null_waiter observer;
  initial begin
    reset_i.rst_n = 1;
    cfg = new;
    cfg.rst_vif = reset_i;
    observer = new;
    observer.cfg = cfg;
    observer.mixed();
    $fatal(1, "null VIF was silently ignored");
  end
endmodule
