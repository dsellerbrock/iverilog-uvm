// IEEE 1800-2023 13.4: a function cannot enable a task. Dynamic
// virtual-interface lowering must retain the ordinary call-legality check.

interface vif_task_from_function_if;
  task automatic touch();
  endtask
endinterface

class vif_task_from_function_runner;
  virtual vif_task_from_function_if vif;

  function void illegal_call();
    vif.touch();
  endfunction
endclass

module sv_vif_task_from_function_fail;
  vif_task_from_function_if only_instance();
  vif_task_from_function_runner runner;

  initial begin
    runner = new;
    runner.vif = only_instance;
    runner.illegal_call();
  end
endmodule
