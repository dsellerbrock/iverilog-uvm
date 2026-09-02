// IEEE 1800-2017/2023 13.5/25.9 negative control: retaining dynamic VIF
// output/inout/ref rows must not make a nonvariable actual writable.
interface vif_task_scalar_copyback_fail_if;
  task automatic update(output int selected,
                        inout int accumulated,
                        ref int referenced);
    selected = 1;
    accumulated += 1;
    referenced += 1;
  endtask
endinterface

module sv_vif_task_scalar_copyback_fail;
  vif_task_scalar_copyback_fail_if concrete();
  virtual vif_task_scalar_copyback_fail_if vif;
  int selected;
  int accumulated;
  int referenced;

  initial begin
    vif = concrete;
    vif.update(17, accumulated, referenced);
    vif.update(selected, 19, referenced);
    vif.update(selected, accumulated, 23);
  end
endmodule
