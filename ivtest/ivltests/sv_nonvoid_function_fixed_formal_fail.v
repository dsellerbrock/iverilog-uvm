// IEEE 1800-2017/2023 7.4.5, 7.6 and 7.7: fixed unpacked arrays associated
// with fixed formals need matching dimension counts/sizes and equivalent
// element types. Pure output direction does not relax those call checks, and
// a function input does not relax the slice direction required by its backing
// array declaration.
module sv_nonvoid_function_fixed_formal_fail;
  int wrong_count[0:2];
  real wrong_type[0:1];
  int direction_source[3:0];
  int result;

  function automatic int write_pair(output int value[1:0]);
    value[1] = 1;
    value[0] = 2;
    return 2;
  endfunction

  function automatic int read_pair(input int value[1:0]);
    return value[1] + value[0];
  endfunction

  initial begin
    result = write_pair(wrong_count);
    result = write_pair(wrong_type);
    result = read_pair(direction_source[0:1]);
  end
endmodule
