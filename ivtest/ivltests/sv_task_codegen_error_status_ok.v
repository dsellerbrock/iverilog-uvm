module sv_task_codegen_error_status_ok;
  int value;

  task automatic increment;
    value = value + 1;
  endtask

  initial begin
    increment();
    if (value !== 1) $fatal(1, "valid task body did not execute");
    $display("PASSED");
  end
endmodule
