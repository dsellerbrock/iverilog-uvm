interface static_init_driver_if;
  logic value;
  task drive();
    static bit initialized = (value = 1);
  endtask
endinterface

module sv_interface_task_mixed_driver_static_init;
  bit source;
  static_init_driver_if idle();
  assign idle.value = source;
  initial begin
    source = 0;
    #1;
    if (idle.value !== 0) $fatal(1, "static initializer overrode the continuous driver");
    $display("PASSED");
    $finish;
  end
endmodule
