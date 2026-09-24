interface double_cont_driver_if;
  logic value;
  logic other;
  task drive(input bit next_value); other = next_value; endtask
endinterface

module sv_interface_task_mixed_driver_double_cont_unsafe;
  bit first_source, second_source;
  double_cont_driver_if idle();
  assign idle.value = first_source;
  assign idle.value = second_source;
endmodule
