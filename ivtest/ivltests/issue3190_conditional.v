class issue3190_c;
endclass

module issue3190_conditional;
  string a = "alpha", b = "beta", s;
  issue3190_c ca, cb, obj;
  logic cond;
  integer calls_a, calls_b;

  function string get_a();
    calls_a = calls_a + 1;
    return a;
  endfunction
  function string get_b();
    calls_b = calls_b + 1;
    return b;
  endfunction
  function issue3190_c get_ca();
    calls_a = calls_a + 1;
    return ca;
  endfunction
  function issue3190_c get_cb();
    calls_b = calls_b + 1;
    return cb;
  endfunction

  task check(input logic c, input integer expected_a, expected_b,
             input string expected_s, input issue3190_c expected_obj);
    cond = c;
    calls_a = 0; calls_b = 0;
    s = cond ? get_a() : get_b();
    if (s != expected_s || calls_a != expected_a || calls_b != expected_b)
      $fatal(1, "string condition %b: [%s] calls %0d %0d", c, s, calls_a, calls_b);
    calls_a = 0; calls_b = 0;
    obj = cond ? get_ca() : get_cb();
    if (obj != expected_obj || calls_a != expected_a || calls_b != expected_b)
      $fatal(1, "class condition %b: calls %0d %0d", c, calls_a, calls_b);
  endtask

  initial begin
    ca = new; cb = new;
    check(1'b1, 1, 0, "alpha", ca);
    check(1'b0, 0, 1, "beta", cb);
    check(1'bx, 1, 1, "", null);
    check(1'bz, 1, 1, "", null);
    s = 1'bx ? a : b;
    if (s != "") $fatal(1, "constant unknown string condition");
    s = 1'bz ? a : a;
    if (s != a) $fatal(1, "constant unknown equal strings");
    b = a; cb = ca;
    check(1'bx, 1, 1, "alpha", ca);
    check(1'bz, 1, 1, "alpha", ca);
    cb = null;
    check(1'bx, 1, 1, "alpha", null);
    obj = 1'bx ? ca : null;
    if (obj != null) $fatal(1, "class versus literal null");
    obj = 1'bz ? null : ca;
    if (obj != null) $fatal(1, "literal null versus class");
    ca = null; cb = null;
    check(1'bx, 1, 1, "alpha", null);
    $display("PASS");
  end
endmodule
