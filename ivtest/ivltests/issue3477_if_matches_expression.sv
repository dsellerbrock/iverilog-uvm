module issue3477_if_matches_expression;
  typedef union tagged { void Invalid; int Valid; } VInt;
  typedef union tagged { void Empty; VInt Nested; } Outer;
  VInt value, invalid;
  Outer outer;
  int calls, x = 42;

  function automatic VInt f(input VInt v);
    calls++;
    return v;
  endfunction

  function automatic VInt change_value();
    value = tagged Valid(9);
    return f(value);
  endfunction

  function automatic Outer wrap(input Outer v);
    calls++;
    return v;
  endfunction

  initial begin
    value = tagged Valid(7);
    if (f(value) matches tagged Valid .x)
      $display("%0d %0d", x, calls);
    else
      $fatal(1, "function result did not match");

    invalid = tagged Invalid;
    if (f(invalid) matches tagged Valid .x)
      $fatal(1, "inactive tag matched");
    else if (x !== 42 || calls !== 2)
      $fatal(1, "wrong else-arm scope or evaluation count");

    if ((f(value)) matches .*) ;
    if (calls !== 3)
      $fatal(1, "wildcard with a null arm must evaluate its subject");

    if (1 + 4 matches .sum) begin
      if (sum !== 5) $fatal(1, "wrong arithmetic result");
    end else $fatal(1, "arithmetic result did not match");

    outer = tagged Nested(value);
    if (wrap(outer) matches tagged Nested .part &&&
        f(part) matches tagged Valid .payload &&& payload == 7) begin
      if (calls !== 5) $fatal(1, "nested subject evaluated more than once");
    end else $fatal(1, "binding was unavailable to a later clause");

    if (f(invalid) matches tagged Valid .x &&& f(value) matches .*)
      $fatal(1, "false clause matched");
    else if (calls !== 6 || x !== 42)
      $fatal(1, "false clause did not short-circuit outside binding scope");

    calls = 0;
    priority if (f(value) matches tagged Valid .x) begin
      if (x !== 7) $fatal(1, "wrong priority payload");
    end else if (change_value() matches tagged Valid .x)
      $fatal(1, "priority selected a later arm");
    if (calls !== 1) $fatal(1, "priority evaluated a later guard");

    priority if (1'bx) $fatal(1, "unknown guard matched");
    else if (f(invalid) matches tagged Valid .x) $fatal(1, "inactive tag matched");
    else begin
      if (x !== 42 || calls !== 2) $fatal(1, "wrong else-arm scope or call count");
    end

    calls = 0;
    unique if (f(value) matches tagged Valid .x) begin
      if (x !== 7 || calls !== 2) $fatal(1, "wrong unique payload or call count");
    end else if (change_value() matches tagged Valid .x)
      $fatal(1, "unique selected a later arm");
    else
      $fatal(1, "unique selected its else arm");

    if (calls !== 2) $fatal(1, "unique evaluated a guard more than once");
    if (recursive_guard(1) !== 2) $fatal(1, "recursive guard clobbered an earlier result");
    $display("PASSED");
  end

  function static int recursive_guard(input int n);
    unique0 if (n + 0 matches 0)
      return 1;
    else if (n == 1 ? recursive_guard(0) == 1 : 1'b0)
      return 2;
    return -1;
  endfunction
endmodule
