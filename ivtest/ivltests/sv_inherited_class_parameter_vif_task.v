// IEEE 1800-2017/2023 8.13 and 25.9: a derived class inherits a base-class
// value parameter, and its unqualified value remains visible when used as an
// actual argument of a task called through a virtual interface. The task
// formal deliberately omits its direction; 13.5 defaults it to input.

interface inherited_class_parameter_clk_if;
  int seen;

  task automatic wait_clks(int num_clks);
    seen = num_clks;
  endtask
endinterface

class inherited_class_parameter_base #(type ITEM_T = int);
  parameter int CyclesWithNoAccessesThreshold = 80;
endclass

class inherited_class_parameter_derived
    extends inherited_class_parameter_base#(byte);
  virtual inherited_class_parameter_clk_if vif;

  task run;
    vif.wait_clks(CyclesWithNoAccessesThreshold * 2);
  endtask
endclass

module sv_inherited_class_parameter_vif_task;
  inherited_class_parameter_clk_if if0();
  inherited_class_parameter_clk_if if1();
  inherited_class_parameter_derived driver;

  initial begin
    driver = new;
    driver.vif = if1;
    driver.run();

    if (if1.seen !== 160 || if0.seen !== 0)
      $fatal(1, "selected=%0d unselected=%0d", if1.seen, if0.seen);

    $display("PASSED");
  end
endmodule
