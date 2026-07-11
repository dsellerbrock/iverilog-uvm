// M1 typed-expression dispatch: builder-style method chaining on class
// handle returns, including nested calls of the SAME method (exercises
// the vvp automatic-context returned-frame fix). IEEE 1800-2017 8.10.
// Reduced from gap audit G32 (probe p84).
module m1_method_chain_builder_test;
  class C;
    int v;
    function C with_v(int x);
      v = x;
      return this;
    endfunction
    function C mul_v(int x);
      v = v * x;
      return this;
    endfunction
  endclass

  initial begin
    C c, c2, r;
    int errors = 0;

    // Two-link chain of the same method.
    c = new;
    r = c.with_v(42).with_v(100);
    if (r != c || c.v !== 100) begin
      $display("FAIL: chain same-method r==c:%0d c.v=%0d", (r == c), c.v);
      errors++;
    end

    // Three-link chain mixing methods, read property off the chain.
    c = new;
    if (c.with_v(5).mul_v(3).with_v(c.v + 1).v !== 16) begin
      $display("FAIL: mixed chain c.v=%0d, expected 16", c.v);
      errors++;
    end

    // Nested same-method call as an argument sub-expression
    // (returned-frame vs pre-allocated same-scope frame).
    c = new;
    c2 = new;
    r = c.with_v(c2.with_v(3).v);
    if (r != c || c.v !== 3 || c2.v !== 3) begin
      $display("FAIL: nested same-method r==c:%0d c.v=%0d c2.v=%0d",
               (r == c), c.v, c2.v);
      errors++;
    end

    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
