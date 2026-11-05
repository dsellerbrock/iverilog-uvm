module issue1790_signed_x_nonlogical;
  logic signed [7:0] signed_value = 8'b000x0001;
  logic        [7:0] unsigned_value = 8'b000x0001;

  initial begin
    $display("unary_plus=%b bitwise_not=%b left_shift=%b",
             +signed_value, ~signed_value, signed_value << 1);

    if ((+signed_value) !== 8'hxx
        || (~signed_value) !== 8'hxx
        || (signed_value << 1) !== 8'hxx)
      $fatal(1, "signed unary plus, bitwise not, and shift must be all X");

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
