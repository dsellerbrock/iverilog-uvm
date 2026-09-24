interface alias_driver_if;
  logic value;
  task drive(input bit next_value); value = next_value; endtask
endinterface

module sv_interface_task_mixed_driver_alias_unsafe;
  bit source;
  alias_driver_if used();
  virtual alias_driver_if alias_handle;
  assign used.value = source;
  initial begin
    alias_handle = used;
    if ($test$plusargs("invoke")) alias_handle.drive(1);
  end
endmodule
