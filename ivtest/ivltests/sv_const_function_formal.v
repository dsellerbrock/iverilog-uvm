module sv_const_function_formal;
  function automatic int input_only(input int value);
    return value + 1;
  endfunction

  function automatic int nested(input int value);
    return input_only(input_only(value));
  endfunction

  localparam int FOLDED = nested(5);

  function automatic int output_runtime(output int value);
    value = 8;
    return value;
  endfunction

  function automatic int inout_runtime(inout int value);
    value += 2;
    return value;
  endfunction

  function automatic int ref_runtime(ref int value);
    value += 4;
    return value;
  endfunction

  function automatic int const_ref_runtime(const ref int value);
    return value + 8;
  endfunction

  initial begin
    int value;
    if (FOLDED != 7) $fatal(1, "input-only constant call failed: %0d", FOLDED);
    if (output_runtime(value) != 8 || value != 8)
      $fatal(1, "runtime output call failed: %0d", value);
    if (inout_runtime(value) != 10 || value != 10)
      $fatal(1, "runtime inout call failed: %0d", value);
    if (ref_runtime(value) != 14 || value != 14)
      $fatal(1, "runtime ref call failed: %0d", value);
    if (const_ref_runtime(value) != 22 || value != 14)
      $fatal(1, "runtime const-ref call failed: %0d", value);
    $display("PASSED");
  end
endmodule
