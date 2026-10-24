task automatic trace_monitor;
  int local_value;
  $monitor(local_value);
endtask

module sv_auto_monitor_trace;
  initial trace_monitor();
endmodule
