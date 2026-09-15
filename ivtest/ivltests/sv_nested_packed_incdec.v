module sv_nested_packed_incdec;
  logic [1:0][1:0][7:0] value;
  logic [3:0] result;
  int outer_calls, inner_calls, base_calls;

  function automatic int outer_index(); outer_calls++; return 0; endfunction
  function automatic int inner_index(); inner_calls++; return 1; endfunction
  function automatic int base_index(); base_calls++; return 6; endfunction
  function automatic logic [1:0][7:0] update_return_slot();
    update_return_slot = 16'ha55a;
    result = update_return_slot[1][3:0]--;
    if (result !== 4'h5 || update_return_slot !== 16'ha45a)
      $fatal(1, "packed function-return update mismatch");
  endfunction

  initial begin
    value = 32'h1122a55a;
    result = value[outer_index()][inner_index()][base_index()+:4]++;
    if (result !== 4'bxx10 || value !== {16'h1122, 8'bxx100101, 8'h5a})
      $fatal(1, "nested result/store mismatch value=%b result=%b", value, result);
    if (outer_calls != 1 || inner_calls != 1 || base_calls != 1)
      $fatal(1, "nested indexes evaluated more than once");
    value = update_return_slot();
    if (value !== 16'ha45a)
      $fatal(1, "packed function-return value mismatch");
    $display("PASSED");
  end
endmodule
