module sv_auto_trace_fail;
  task automatic monitor_task;
    int monitor_local;
    $monitor(monitor_local);
  endtask

  task automatic dump_task;
    int dump_local;
    $dumpvars(0, dump_local);
  endtask

  initial begin
    monitor_task();
    dump_task();
  end
endmodule
