class issue3365_Target;
  rand int x;
endclass

module issue3365_local_scope;
  issue3365_Target obj;
  int x = 23, scope_value;

  initial begin
    obj = new;
    if (!std::randomize(scope_value) with {
      if (local::x > 0) { scope_value == local::x; }
    })
      $fatal(1, "std::randomize failed");
    if (scope_value !== 23)
      $fatal(1, "std::randomize produced %0d, expected 23", scope_value);

    if (!obj.randomize() with (x) { x == local::x + 1; })
      $fatal(1, "identifier-scoped randomize failed");
    if (obj.x !== 24 || x !== 23)
      $fatal(1, "expected target x=24 and caller x=23, got %0d and %0d", obj.x, x);

    void'(obj.randomize() with { x == local::x + 2; });
    if (obj.x !== 25)
      $fatal(1, "discarded-result randomize produced %0d, expected 25", obj.x);

    $display("PASSED");
  end
endmodule
