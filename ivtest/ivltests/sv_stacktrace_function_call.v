module sv_stacktrace_function_call;
  string trace;

  initial begin
    trace = $stacktrace;
    if (trace.len() < 12 || trace.substr(0, 11) != "$stacktrace:")
      $fatal(1, "unexpected $stacktrace function result: '%s'", trace);
    $display("PASS sv_stacktrace_function_call");
  end
endmodule
