module issue781_pattern_conditional;
  typedef union tagged { void Invalid; int Valid; } VInt;
  typedef union tagged { void Invalid; logic [31:0] Valid; } FourStateVInt;
  VInt value;
  FourStateVInt four_state_value;
  int result;
  int n;
  logic [31:0] unknown_result;

  function int replace_value();
    value = tagged Valid(9);
    return 1;
  endfunction

  function automatic int extract_value(input int raw);
    VInt local_value;
    local_value = tagged Valid(raw);
    return local_value matches tagged Valid .item ? item : -1;
  endfunction

  initial begin
    n = 77;
    value = tagged Valid(5);
    result = value matches tagged Valid .n ? n : -1;
    if (result != 5)
      $fatal(1, "pattern consequent value=%0d", result);

    value = tagged Valid(5);
    result = value matches tagged Valid .n
             ? (replace_value() && (n == 5)) : 0;
    if (result != 1)
      $fatal(1, "pattern binding was not captured before consequent: %0d",
             result);

    value = tagged Valid(0);
    result = value matches tagged Valid .n ? n : -1;
    if (result != 0)
      $fatal(1, "zero-valued pattern binding=%0d", result);

    four_state_value = tagged Valid('x);
    unknown_result = four_state_value matches tagged Valid .n ? n : '0;
    if (!$isunknown(unknown_result))
      $fatal(1, "unknown pattern binding was not captured: %0h",
             unknown_result);

    value = tagged Invalid;
    result = value matches tagged Valid .n ? n : n;
    if (result != 77)
      $fatal(1, "pattern scope leaked into false arm: %0d", result);

    if (extract_value(8) != 8 || extract_value(22) != 22)
      $fatal(1, "automatic pattern binding lifetime failed");

    $display("issue781 pattern conditional passed");
  end
endmodule
