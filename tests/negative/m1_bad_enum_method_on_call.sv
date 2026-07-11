// NEGATIVE test: applying an unknown enumeration method to an
// enum-typed function result must produce a compile-time diagnostic
// (IEEE 1800-2017 6.19.5). Expected: compilation FAILS.
module m1_bad_enum_method_on_call;
  typedef enum { A, B } e_t;

  function automatic e_t f(e_t x);
    return x;
  endfunction

  initial begin
    string s;
    s = f(A).not_an_enum_method();
  end
endmodule
