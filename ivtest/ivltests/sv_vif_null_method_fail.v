// IEEE 1800-2023 25.9 requires a fatal run-time error when any component of
// a null virtual interface is used. The existence of exactly one compatible
// real interface instance must not turn a null method receiver into an
// implicit static call.

interface vif_null_method_if;
  int calls = 0;

  task automatic touch();
    calls += 1;
  endtask
endinterface

class vif_null_method_runner;
  virtual vif_null_method_if vif;

  task run();
    vif.touch();
  endtask
endclass

module sv_vif_null_method_fail;
  vif_null_method_if only_instance();
  vif_null_method_runner runner;

  initial begin
    runner = new;
    // runner.vif intentionally retains its specified initial null value.
    runner.run();
    $display("FAILED -- null virtual-interface method call returned");
  end
endmodule
