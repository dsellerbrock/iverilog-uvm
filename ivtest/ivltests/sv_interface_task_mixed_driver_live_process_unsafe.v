interface live_process_driver_if;
  logic value;
  task drive(input bit next_value); value = next_value; endtask
endinterface

module sv_interface_task_mixed_driver_live_process_unsafe;
  bit source;
  live_process_driver_if idle();
  assign idle.value = source;
  initial idle.value = 1;
endmodule
