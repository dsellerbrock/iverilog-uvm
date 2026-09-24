interface unused_driver_if;
  logic value;
  task drive(input bit next_value); value = next_value; endtask
endinterface

module sv_interface_task_mixed_driver_unused_unsafe;
  bit source;
  logic unrelated;
  unused_driver_if idle();
  task automatic write_ref(ref logic target); target = 1'b1; endtask
  assign idle.value = source;
  initial begin
    write_ref(unrelated);
    if (unrelated !== 1'b1) $fatal(1, "unrelated ref call failed");
    source = 0;
    #1;
    if (idle.value !== 0) $fatal(1, "unused task disturbed continuous zero");
    source = 1;
    #1;
    if (idle.value !== 1) $fatal(1, "unused task disturbed continuous one");
    $display("PASSED");
    $finish(0);
  end
endmodule
