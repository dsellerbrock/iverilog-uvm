// NEGATIVE test: calling an unknown method on a class-valued
// function-call result must produce a compile-time diagnostic, not a
// silent stub (IEEE 1800-2017 8.10; manifesto principle 4).
// Expected: compilation FAILS mentioning `no_such_method`.
module m1_bad_method_on_call_result;
  class C;
    int v;
    function int get_v();
      return v;
    endfunction
  endclass

  function automatic C make_c();
    C c = new;
    return c;
  endfunction

  initial begin
    int x;
    x = make_c().no_such_method();
  end
endmodule
