interface sibling_driver_if;
  logic value;
  task drive(input bit next_value); value = next_value; endtask
endinterface

module sv_interface_task_mixed_driver_sibling_unsafe;
  bit idle_source, used_source;
  sibling_driver_if idle(), used();
  assign idle.value = idle_source;
  assign used.value = used_source;
  initial used.drive(1);
endmodule
