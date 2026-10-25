module sv_auto_task_trace_fail_2017;
  task automatic trace_local;
    int value;
    $monitor(value);
    $dumpvars(0, value);
  endtask

  initial trace_local();
endmodule
