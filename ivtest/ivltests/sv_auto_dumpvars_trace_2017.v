task automatic trace_dumpvars;
  int local_value;
  $dumpvars(0, local_value);
endtask

module sv_auto_dumpvars_trace;
  initial trace_dumpvars();
endmodule
