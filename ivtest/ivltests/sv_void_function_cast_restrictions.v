module sv_void_function_cast_restrictions;
  task automatic not_a_function; endtask
  function automatic void no_value(); endfunction
  int value;
  initial begin
    void'(not_a_function());
    value = no_value();
  end
endmodule
