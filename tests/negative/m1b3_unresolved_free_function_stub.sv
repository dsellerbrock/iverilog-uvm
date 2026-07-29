// NEGATIVE test (M1B-3 / Finding D): a call to a free function that
// does not exist anywhere must produce a compile-time diagnostic, not
// compile clean via the UVM-library-only compile-progress
// unresolved-function-name classifier. get_max_size() string-matches
// one of the classifier's hardcoded literals; before the fix this
// silently fabricated 0 instead of erroring.
// Expected: compilation FAILS mentioning `get_max_size` / no function.
module m1b3_unresolved_free_function_stub;
  initial begin
    int i;
    i = get_max_size();
  end
endmodule
