// Regression: chained method-call STATEMENT preserves the receiver.
//
// `(o.get_i()).set_v(5);` — a method call applied to the result of another
// call, used as a statement — previously hit parse.y's expr_primary-method
// rule whose else-branch DISCARDED the subject expression, so the method was
// emitted as a bare task name ("Enable of unknown task set_v ignored") and the
// receiver never saw the call.  Now the receiver is kept as the PCallTask
// subject and the method dispatches on its type.
//
// The bare (no-paren) form `o.get_i().set_v(5);` is covered separately once
// the statement-context parse conflict is also resolved; this test pins the
// elaboration/semantics half via the already-parsing parens form.
module top;

  class inner;
    int v;
    function void set_v(int x); v = x; endfunction
  endclass

  class outer;
    inner i;
    function new(); i = new(); endfunction
    function inner get_i(); return i; endfunction
  endclass

  initial begin
    outer o;
    int errors = 0;
    o = new();

    // method call on a function-call result (statement)
    (o.get_i()).set_v(5);
    if (o.i.v != 5) begin
      $display("FAIL: parens chained call, v=%0d (expected 5)", o.i.v);
      errors++;
    end

    // a second call to confirm the receiver is the live object each time
    (o.get_i()).set_v(42);
    if (o.i.v != 42) begin
      $display("FAIL: parens chained call 2, v=%0d (expected 42)", o.i.v);
      errors++;
    end

    if (errors == 0) $display("PASS");
    else $display("FAILED with %0d errors", errors);
  end
endmodule
