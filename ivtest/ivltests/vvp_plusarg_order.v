// vvp command-line layout (Documentation/usage/vvp_flags.rst): options come
// before the input file, and every argument after it is an extended argument.
// A +plusarg may also precede the options, as test runners such as dvsim do.
module top;
  integer n;
  initial begin
    if (!$test$plusargs("pre")) $display("FAILED: leading plusarg missing");
    else if (!$value$plusargs("post=%d", n) || n != 7)
      $display("FAILED: trailing plusarg missing");
    else if (!$test$plusargs("vcd") && !$test$plusargs("none"))
      $display("PASSED");
    else $display("FAILED: dash argument seen as plusarg");
  end
endmodule
