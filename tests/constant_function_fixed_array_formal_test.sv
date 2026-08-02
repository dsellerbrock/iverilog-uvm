package constant_function_fixed_array_formal_pkg;
  parameter int Count = 3;
  parameter int Values[Count] = '{2, 7, 4};

  function automatic int max_value(int values[Count]);
    int current_max = 0;
    for (int i = 0; i < Count; i++) begin
      if (values[i] > current_max)
        current_max = values[i];
    end
    return current_max;
  endfunction

  parameter int Maximum = max_value(Values);
endpackage

module constant_function_fixed_array_formal_test;
  import constant_function_fixed_array_formal_pkg::*;

  initial begin
    if (Maximum !== 7)
      $fatal(1, "fixed-array constant-function argument failed: %0d", Maximum);
    $display("PASS: fixed unpacked-array constant-function input");
  end
endmodule
