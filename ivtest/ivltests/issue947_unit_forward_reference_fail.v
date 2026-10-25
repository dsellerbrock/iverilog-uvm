task unit_forward_task;
  int value;
  value = $unit::unit_forward_task_var;
endtask

module unit_forward_module;
  int value = $unit::unit_forward_module_var;
endmodule

bit unit_forward_task_var;
bit unit_forward_module_var;
