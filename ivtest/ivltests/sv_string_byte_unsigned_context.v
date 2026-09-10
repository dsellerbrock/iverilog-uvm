// Signed character operands must still follow the surrounding expression rules.
module sv_string_byte_unsigned_context;
  string s;
  logic signed [7:0] packed_value;
  integer actual;
  initial begin
    s = "\377"; packed_value = -1;
    actual = packed_value[7:0];
    if (actual != 255) $fatal(1, "packed part select changed");
    actual = packed_value[7];
    if (actual != 1) $fatal(1, "packed bit select changed");
    actual = {s[0]};
    if (actual != 255) $fatal(1, "concatenation unsigned");
    if (s[0] + 32'd1 != 256) $fatal(1, "mixed unsigned context");
    actual = $unsigned(s[0]);
    if (actual != 255) $fatal(1, "explicit unsigned cast");
    actual = byte'(s[0]);
    if (actual != -1) $fatal(1, "explicit byte cast");
    $display("PASSED");
  end
endmodule
