module sv_const_function_generate_nested_fail;
  if (1) begin : generated
    begin : nested_scope
      function automatic int inner(input int value);
        return value + 1;
      endfunction
      function automatic int outer(input int value);
        return inner(value) + 1;
      endfunction
      localparam int VALUE = outer(5);
    end
  end
endmodule
