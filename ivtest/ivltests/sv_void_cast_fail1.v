// A void function cannot supply an expression value. Legal dedicated
// void-call statements are covered by sv_void_function_cast_statement.

module test;

  int result;

  function void f(int x);
  endfunction

  initial begin
    result = f(10);
  end

endmodule
