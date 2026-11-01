module issue1816_function_ref_array_element;
  int arr[4];
  int idx;
  int got;

  function automatic int f_ref(ref int value);
    idx = 2;
    arr[1] = 31;
    return value;
  endfunction

  function automatic int f_const_ref(const ref int value);
    idx = 2;
    arr[1] = 32;
    return value;
  endfunction

  task automatic t_ref(ref int value, input int replacement);
    idx = 2;
    arr[1] = replacement;
    got = value;
  endtask

  task automatic t_const_ref(const ref int value, input int replacement);
    idx = 2;
    arr[1] = replacement;
    got = value;
  endtask

  initial begin
    idx = 1;
    if (f_ref(arr[idx]) != 31) $fatal(1, "function ref variable index");
    arr[1] = 0;
    if (f_ref(arr[1]) != 31) $fatal(1, "function ref constant index");
    arr[1] = 0;
    idx = 1;
    if (f_const_ref(arr[idx]) != 32)
      $fatal(1, "function const ref variable index");
    arr[1] = 0;
    if (f_const_ref(arr[1]) != 32)
      $fatal(1, "function const ref constant index");

    arr[1] = 0;
    idx = 1;
    t_ref(arr[idx], 41);
    if (got != 41) $fatal(1, "task ref variable index");
    arr[1] = 0;
    t_ref(arr[1], 42);
    if (got != 42) $fatal(1, "task ref constant index");
    arr[1] = 0;
    idx = 1;
    t_const_ref(arr[idx], 43);
    if (got != 43) $fatal(1, "task const ref variable index");
    arr[1] = 0;
    t_const_ref(arr[1], 44);
    if (got != 44) $fatal(1, "task const ref constant index");

    $display("passed");
  end
endmodule
