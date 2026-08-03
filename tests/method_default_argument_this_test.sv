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
    assert (a.value_or_default(41) == 41);
    assert (b.value_or_default() == 93);
    assert (a.value_or_default() == 17);
    assert (a.self_check());
    assert (b.self_check());
    $display("PASS method default argument this");
  end
endmodule
