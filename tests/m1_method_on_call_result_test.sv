// M1 typed-expression dispatch: method calls and property access on
// class-valued function-call results (IEEE 1800-2017 8.10, 13.4.1).
// Reduced from UVM factory/builder failures (gap audit G22/G32).
module m1_method_on_call_result_test;
  int side_hits = 0;

  class C;
    int v;
    function int get_v();
      return v;
    endfunction
    function void bump();
      side_hits = side_hits + 1;
    endfunction
  endclass

  function automatic C make_c(int x);
    C c = new;
    c.v = x;
    return c;
  endfunction

  initial begin
    int errors = 0;

    // Method call on a function-call result.
    if (make_c(42).get_v() !== 42) begin
      $display("FAIL: make_c(42).get_v() = %0d, expected 42", make_c(42).get_v());
      errors++;
    end

    // Property access on a function-call result.
    if (make_c(7).v !== 7) begin
      $display("FAIL: make_c(7).v = %0d, expected 7", make_c(7).v);
      errors++;
    end

    // Void-method-call statement on a function-call result.
    make_c(1).bump();
    if (side_hits !== 1) begin
      $display("FAIL: void method statement ran %0d times, expected 1", side_hits);
      errors++;
    end

    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
