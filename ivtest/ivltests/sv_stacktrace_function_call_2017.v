module sv_stacktrace_function_call_2017;
  string trace;

  initial trace = $stacktrace;
endmodule
