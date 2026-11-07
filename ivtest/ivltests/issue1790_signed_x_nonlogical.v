module issue1790_signed_x_nonlogical;
  logic signed [7:0] signed_value = 8'b000x0001;
  logic        [7:0] unsigned_value = 8'b000x0001;
  logic        [7:0] unsigned_zero = 8'b0;
  logic signed [7:0] r_plus, r_not, r_shl, r_neg;
  logic        [7:0] r_ctx;

  initial begin
    #1;
    // The right-hand side alone decides signedness (11.8.1), so each of
    // these operations sees a signed operand with an X bit (11.8.4).
    r_plus = +signed_value;
    r_not  = ~signed_value;
    r_shl  = signed_value << 1;
    r_neg  = -signed_value;
    $display("unary_plus=%b bitwise_not=%b left_shift=%b",
             r_plus, r_not, r_shl);
    if (r_plus !== 8'hxx || r_not !== 8'hxx || r_shl !== 8'hxx
        || r_neg !== 8'hxx)
      $fatal(1, "signed unary plus, minus, bitwise not and shift must be all X");

    // An unsigned operand in the context converts signed_value to unsigned
    // before the shift (11.8.2), so ordinary four-state rules apply.
    r_ctx = (signed_value << 1) | unsigned_zero;
    if (r_ctx !== 8'b00x00010)
      $fatal(1, "unsigned context must convert the operand first: %b", r_ctx);

    if ((+unsigned_value) !== unsigned_value
        || (~unsigned_value) !== 8'b111x1110
        || (unsigned_value << 1) !== 8'b00x00010)
      $fatal(1, "unsigned X results must retain ordinary four-state behavior");

    if ((signed_value && 1'b0) !== 1'b0
        || (signed_value || 1'b1) !== 1'b1)
      $fatal(1, "logical operators must retain logical semantics");

    $display("PASS: signed X nonlogical results are all X");
  end
endmodule
