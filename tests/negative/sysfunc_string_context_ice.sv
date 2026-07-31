// A system function that does not return a string, used where a string
// is required. This aborted the COMPILER with a raw assertion failure
// (eval_string.c:364, exit 134) rather than diagnosing the source -- a
// plain typo like `s = $bogus();' was enough to trigger it. It must now
// be a clean, located error.
module sysfunc_string_context_ice;
  string s;
  initial begin
    s = $time();
    $display("%s", s);
  end
endmodule
