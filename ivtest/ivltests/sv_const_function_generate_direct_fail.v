module sv_const_function_generate_direct_fail;
  if (1) begin : generated
    function automatic int helper(input int value);
      return value + 1;
    endfunction
    localparam int VALUE = helper(6);
  end
endmodule
