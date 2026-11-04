module issue752_static_init_explicit;
  int module_init = 1;

  task automatic automatic_task;
    int task_init = 4;
    $display("task=%0d", task_init);
  endtask

  initial begin
    static int static_init = 2;
    automatic int automatic_init = 3;
    $display("module=%0d static=%0d automatic=%0d",
             module_init, static_init, automatic_init);
    automatic_task();
  end
endmodule
