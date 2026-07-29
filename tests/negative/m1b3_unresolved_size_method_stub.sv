// NEGATIVE test (M1B-3 / Finding D): calling .size() on a class that
// has no size() method must produce a compile-time diagnostic, not
// compile clean via the UVM-library-only compile-progress method-name
// classifier's unconditional "size/num -> 0" rule (which used to fire
// for ANY class, not just real queues/mailboxes/uvm collections).
// Expected: compilation FAILS mentioning `size` / `no method`.
module m1b3_unresolved_size_method_stub;
  class Widget;
  endclass

  initial begin
    Widget w = new;
    int n;
    n = w.size();
  end
endmodule
