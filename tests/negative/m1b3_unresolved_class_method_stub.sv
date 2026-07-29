// NEGATIVE test (M1B-3 / Finding D): a call to a method that does not
// exist on an ordinary user class must produce a compile-time
// diagnostic, not compile clean via the UVM-library-only
// compile-progress method-name classifier. get_name() string-matches
// one of the classifier's ~50 hardcoded literals; before the fix this
// silently fabricated an empty string instead of erroring.
// Expected: compilation FAILS mentioning `get_name` / `no method`.
module m1b3_unresolved_class_method_stub;
  class Foo;
  endclass

  initial begin
    Foo f = new;
    string s;
    s = f.get_name();
  end
endmodule
