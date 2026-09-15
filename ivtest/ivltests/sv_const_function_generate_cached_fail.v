module sv_const_function_generate_cached_fail;
  if (1) begin : generated
    function automatic int helper(input int value);
      return value + 1;
    endfunction
    int runtime_value = helper(2);
    localparam int VALUE = helper(6);
    initial if (runtime_value != 3) $fatal(1, "runtime call changed");
  end
endmodule
