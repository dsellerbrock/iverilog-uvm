module sv_const_function_generate_for_fail;
  for (genvar index = 0; index < 1; index++) begin : generated
    function automatic int helper(input int value);
      return value + 1;
    endfunction
    localparam int VALUE = helper(index);
  end
endmodule
