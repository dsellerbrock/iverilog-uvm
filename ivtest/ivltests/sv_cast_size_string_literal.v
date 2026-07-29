// IEEE 1800-2017 5.9: a string literal is a packed array of bytes, and in
// a context that wants an integral value it behaves as an unsigned integer
// constant. A size cast of a string literal -- `64'("GAL_XOR")' -- is
// therefore an ordinary size cast of a vector.
//
// OpenTitan's prim_lfsr selects its polynomial type this way:
//     if (64'(LfsrType) == 64'("GAL_XOR")) ...
// which is how the LFSR (and therefore AES, and everything that
// instantiates one) picks its implementation.

module sv_cast_size_string_literal;

  localparam LfsrType = "GAL_XOR";

  int errors = 0;

  initial begin
    // "GAL_XOR" is 7 characters -> 56 bits, zero-extended to 64.
    if (64'("GAL_XOR") !== 64'h0047_414c_5f58_4f52) begin
      $display("FAILED -- 64'(\"GAL_XOR\") gave %h, want 0047414c5f584f52",
               64'("GAL_XOR"));
      errors++;
    end

    // The comparison prim_lfsr actually performs.
    if (!(64'(LfsrType) == 64'("GAL_XOR"))) begin
      $display("FAILED -- 64'(LfsrType) == 64'(\"GAL_XOR\") did not hold");
      errors++;
    end

    // A cast narrower than the literal must truncate to the low bytes.
    if (16'("AB") !== 16'h4142) begin
      $display("FAILED -- 16'(\"AB\") gave %h, want 4142", 16'("AB"));
      errors++;
    end

    // A different string must not compare equal.
    if (64'("GAL_XOR") == 64'("FIB_XNOR")) begin
      $display("FAILED -- distinct string literals compared equal");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    $finish(0);
  end

endmodule
