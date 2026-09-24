interface indirect_driver_if;
  logic value;
  task drive(input bit next_value); value = next_value; endtask
endinterface

module sv_interface_task_mixed_driver_indirect_unsafe;
  bit source;
  indirect_driver_if used();
  assign used.value = source;
  task invoke(); used.drive(1); endtask
  initial invoke();
endmodule
