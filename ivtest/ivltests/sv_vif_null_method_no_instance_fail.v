// A virtual-interface method call must fail at run time even when the design
// contains no concrete instance of the interface type. The interface
// declaration alone must not turn a null receiver into a warning/no-op.

interface vif_null_no_instance_if;
  task automatic touch();
  endtask
endinterface

class vif_null_no_instance_runner;
  virtual vif_null_no_instance_if vif;

  task run();
    vif.touch();
  endtask
endclass

module sv_vif_null_method_no_instance_fail;
  vif_null_no_instance_runner runner;

  initial begin
    runner = new;
    runner.run();
    $display("FAILED -- null virtual-interface method call returned");
  end
endmodule
