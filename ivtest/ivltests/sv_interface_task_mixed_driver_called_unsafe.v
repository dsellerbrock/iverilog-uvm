interface called_driver_if;
  logic value;
  task drive(input bit next_value); value = next_value; endtask
endinterface

module sv_interface_task_mixed_driver_called_unsafe;
  bit source;
  called_driver_if used();
  assign used.value = source;
  initial used.drive(1);
endmodule
