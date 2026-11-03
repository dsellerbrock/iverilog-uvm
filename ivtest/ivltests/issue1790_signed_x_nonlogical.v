module main;
  logic signed [7:0] signed_x = 8'b000x0001;
  logic signed [7:0] signed_z = 8'b000z0001;
  logic [7:0] unsigned_x = 8'b000x0001;
  logic signed [7:0] bitwise_or;
  logic signed [7:0] bitwise_xor;

  initial begin
    if ((+signed_x) !== 8'hxx)
      $fatal(1, "signed unary plus was %b", +signed_x);
    if ((~signed_x) !== 8'hxx)
      $fatal(1, "signed bitwise NOT was %b", ~signed_x);
    if ((signed_x << 1) !== 8'hxx)
      $fatal(1, "signed left shift was %b", signed_x << 1);

    bitwise_or = signed_x | 8'shff;
    bitwise_xor = signed_x ^ 8'sh00;
    if (bitwise_or !== 8'hxx || bitwise_xor !== 8'hxx)
      $fatal(1, "signed bitwise result was %b / %b", bitwise_or,
             bitwise_xor);

    if ((+signed_z) !== 8'hxx)
      $fatal(1, "signed unary plus with Z was %b", +signed_z);
    if ((~signed_z) !== 8'hxx)
      $fatal(1, "signed bitwise NOT with Z was %b", ~signed_z);
    if ((signed_z << 1) !== 8'hxx)
      $fatal(1, "signed left shift with Z was %b", signed_z << 1);

    if ((+unsigned_x) !== 8'b000x0001
        || (~unsigned_x) !== 8'b111x1110
        || (unsigned_x << 1) !== 8'b00x00010)
      $fatal(1, "unsigned X operand was over-poisoned");
    if ((signed_x && 1'b0) !== 1'b0)
      $fatal(1, "logical operation was over-poisoned");
    if ((+8'sb000x0001) !== 8'hxx
        || (~8'sb000x0001) !== 8'hxx
        || (8'sb000x0001 << 0) !== 8'hxx)
      $fatal(1, "constant-folded signed X result was not all X");

    $display("PASSED");
    $finish;
  end
endmodule
