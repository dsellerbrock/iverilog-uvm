module sv_void_function_in_constant_function;
  function void side_effect;
  endfunction

  function integer constant_function;
    side_effect();
    constant_function = 1;
  endfunction

  localparam integer VALUE = constant_function();

  initial $display("VALUE=%0d", VALUE);
endmodule
