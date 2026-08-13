module test;
  logic [7:0] a;
  logic [7:0] b;
  logic [7:0] result;
  logic [3:0] nibble;
  logic signed [7:0] signed_value;
  int calls;

  function automatic logic [7:0] next_value();
    calls += 1;
    return 8'd3;
  endfunction

  initial begin
    a = 8'd5;
    result = (a = 8'd9);
    if (a != 9 || result != 9) $fatal(1, "simple assignment expression");

    result = (a += 3);
    if (a != 12 || result != 12) $fatal(1, "+= expression");
    result = (a -= 2);
    if (a != 10 || result != 10) $fatal(1, "-= expression");
    result = (a *= 3);
    if (a != 30 || result != 30) $fatal(1, "*= expression");
    result = (a /= 5);
    if (a != 6 || result != 6) $fatal(1, "/= expression");
    result = (a %= 4);
    if (a != 2 || result != 2) $fatal(1, "modulo assignment expression");
    result = (a |= 8);
    if (a != 10 || result != 10) $fatal(1, "|= expression");
    result = (a &= 6);
    if (a != 2 || result != 2) $fatal(1, "&= expression");
    result = (a ^= 3);
    if (a != 1 || result != 1) $fatal(1, "^= expression");
    result = (a <<= 3);
    if (a != 8 || result != 8) $fatal(1, "<<= expression");
    result = (a >>= 2);
    if (a != 2 || result != 2) $fatal(1, ">>= expression");

    signed_value = -16;
    result = (signed_value >>>= 2);
    if (signed_value != -4 || result != 8'hfc)
      $fatal(1, ">>>= expression");

    a = 0;
    b = 0;
    result = (a = (b = 17));
    if (a != 17 || b != 17 || result != 17)
      $fatal(1, "nested assignment expressions");

    a = 1;
    b = 2;
    result = (b += (a += 3) + 4);
    if (a != 4 || b != 10 || result != 10)
      $fatal(1, "nested compound assignment expressions");

    nibble = 0;
    result = (nibble = 8'h2f);
    if (nibble != 4'hf || result != 8'h0f)
      $fatal(1, "l-value conversion before expression result");

    calls = 0;
    a = 1;
    result = (a += next_value());
    if (calls != 1 || a != 4 || result != 4)
      $fatal(1, "right-hand side evaluated more than once");

    $display("PASSED");
  end
endmodule
