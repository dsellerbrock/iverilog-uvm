interface strict_driver_if;
  logic value;
  task drive(input bit next_value); value = next_value; endtask
endinterface

module sv_interface_task_mixed_driver_strict;
  bit source;
  strict_driver_if idle();
  assign idle.value = source;
endmodule
