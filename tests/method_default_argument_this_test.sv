class default_arg_item;
  int value;

  function int get_value();
    return value;
  endfunction

  function int value_or_default(int arg = get_value());
    return arg;
  endfunction

  function bit self_check();
    return value_or_default() == value;
  endfunction
endclass

module method_default_argument_this_test;
  initial begin
    default_arg_item a, b;
    a = new;
    b = new;
    a.value = 17;
    b.value = 93;

    // Prime the same automatic function with another receiver.  Before the
    // fix, the next default expression observed that stale receiver.
    if (a.value_or_default(41) !== 41)
      $fatal(1, "explicit method argument changed");
    if (b.value_or_default() !== 93)
      $fatal(1, "default argument used the wrong receiver");
    if (a.value_or_default() !== 17)
      $fatal(1, "default argument used a stale receiver");
    if (!a.self_check())
      $fatal(1, "self-check used the wrong receiver");
    if (!b.self_check())
      $fatal(1, "second self-check used the wrong receiver");
    $display("PASS method default argument this");
  end
endmodule
