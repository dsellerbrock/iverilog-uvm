// Regression witness for the symbol-search cache identity defect: the
// cache was keyed on the ADDRESS of the AST path object, so when one
// expression node was freed and another was allocated at the same
// address, a call like obj.predict(...) could silently resolve to a
// neighboring method (obj.get_access) that had been looked up earlier
// in the same scope. The cache is now keyed on the query content.
//
// This test exercises the aliasing-prone shape: many dotted method
// calls through the same receiver with different tails, from inside a
// class method in a package, with results value-checked so any
// mis-dispatch is a hard failure.
package p;
  class base;
    function int alpha(int x, int y = 1);
      return x + y;
    endfunction
    function int beta(int x = 10);
      return x * 2;
    endfunction
    function int gamma();
      return 7;
    endfunction
  endclass

  class user;
    function int run(base b);
      int acc;
      if (b.gamma() == 7) begin
        base inner = b;
        acc = inner.alpha(3);          // 4
        acc += inner.beta();           // +20
        acc += inner.alpha(2, .y(5));  // +7
        acc += inner.beta(.x(4));      // +8
        acc += inner.gamma();          // +7
      end
      return acc;                      // 46
    endfunction
  endclass
endpackage

module main;
  initial begin
    p::base b = new;
    p::user u = new;
    if (u.run(b) !== 46) $display("FAILED r=%0d", u.run(b));
    else $display("PASSED");
  end
endmodule
