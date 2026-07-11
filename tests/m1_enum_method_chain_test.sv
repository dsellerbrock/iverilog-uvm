// M1 typed-expression dispatch: enumeration methods applied to
// function-call results and to other enum-method results
// (IEEE 1800-2017 6.19.5). Reduced from gap audit G31 (probe p32).
module m1_enum_method_chain_test;
  typedef enum { RED, GREEN, BLUE } color_t;

  function automatic color_t next_color(color_t c);
    return c.next();
  endfunction

  initial begin
    color_t c;
    string s;
    int errors = 0;

    c = RED;

    // Enum method on a user-function result.
    s = next_color(c).name();
    if (s != "GREEN") begin
      $display("FAIL: next_color(RED).name() = %s, expected GREEN", s);
      errors++;
    end

    // Enum method chained on an enum-method result.
    s = c.next().name();
    if (s != "GREEN") begin
      $display("FAIL: RED.next().name() = %s, expected GREEN", s);
      errors++;
    end

    // Deeper chain: next().next() wraps modulo the enum.
    if (c.next().next() !== BLUE) begin
      $display("FAIL: RED.next().next() != BLUE");
      errors++;
    end

    // Value-returning chain into num()/name() composition.
    s = next_color(next_color(c)).name();
    if (s != "BLUE") begin
      $display("FAIL: next_color(next_color(RED)).name() = %s, expected BLUE", s);
      errors++;
    end

    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
