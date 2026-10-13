// A ref open-array formal is not equivalent to a fixed-size array actual
// (IEEE 1800-2017/2023 6.22.2 and 13.5.2).
module sv_ref_open_array_function_actual_fail;
  int fixed_actual[3];

  function automatic int read_ref(ref int value[]);
    return value[0];
  endfunction

  initial begin
    int result;
    result = read_ref(fixed_actual);
  end
endmodule
