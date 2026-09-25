// IEEE 1800-2017/2023 13.5: an output actual must be an assignable lvalue.
module sv_function_output_nonlvalue_fail;
  function automatic int read_wide(output logic [31:0] data);
    data = 'x;
    return 1;
  endfunction

  initial begin
    int ignored;
    ignored = read_wide(32'h12345678);
  end
endmodule
