// Regression: BARE chained method-call statement f(...).method(...).
//
// Without the dedicated subroutine_call rule, `f(...)` reduces as a complete
// call and the trailing `.method(...)` cannot attach, so the bare form was a
// "syntax error / Malformed statement" (only the parenthesised form
// `(f(...)).method(...)` reached the expr_primary rule). This covers both
// shapes: a function-call receiver and an object-method receiver, mirroring
// OpenTitan's rv_timer DV idiom `reg.get_field_by_name("x").set(v);`.
//
// The leading call is built as a PECallFunction subject so the trailing method
// dispatches on its (class) type.
module top;

  class field_h;
    int v;
    function void set(int x); v = x; endfunction
  endclass

  class reg_h;
    field_h f;
    function new(); f = new(); endfunction
    function field_h get_field_by_name(string n); return f; endfunction
  endclass

  field_h g_field;
  function field_h make_field(); return g_field; endfunction

  initial begin
    reg_h r;
    int errors = 0;
    g_field = new();
    r = new();

    // obj.method(args).method(args)  (rv_timer get_field_by_name(...).set(...))
    r.get_field_by_name("prescale").set(7);
    if (r.f.v != 7) begin
      $display("FAIL: obj.method().method(), v=%0d (exp 7)", r.f.v);
      errors++;
    end

    // func(args).method(args)  (module function receiver)
    make_field().set(99);
    if (g_field.v != 99) begin
      $display("FAIL: func().method(), v=%0d (exp 99)", g_field.v);
      errors++;
    end

    if (errors == 0) $display("PASS");
    else $display("FAILED with %0d errors", errors);
  end
endmodule
