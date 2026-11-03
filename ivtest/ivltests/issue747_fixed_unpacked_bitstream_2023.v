module issue747_fixed_unpacked_bitstream;
  typedef byte b4_t[4];
  typedef byte rev_b4_t[3:0];
  typedef byte matrix_t[1:0][0:1];
  typedef logic [7:0] l4_t[4];
  typedef logic [31:0] logic32_t;

  b4_t bytes;
  byte dynamic_bytes[];
  rev_b4_t reverse_bytes;
  matrix_t matrix;
  l4_t logic_bytes;
  byte two_state_bytes[4];
  int iv;
  logic32_t packed_value;

  initial begin
    bytes = b4_t'(32'h01020304);
    if (bytes[0] !== 8'h01 || bytes[1] !== 8'h02
        || bytes[2] !== 8'h03 || bytes[3] !== 8'h04)
      $fatal(1, "fixed-array destination order");
    iv = int'(bytes);
    if (iv !== 32'h01020304)
      $fatal(1, "fixed-array source order: %08h", iv);

    dynamic_bytes = new[4];
    dynamic_bytes[0] = 8'h05;
    dynamic_bytes[1] = 8'h06;
    dynamic_bytes[2] = 8'h07;
    dynamic_bytes[3] = 8'h08;
    bytes = b4_t'(dynamic_bytes);
    if (bytes[0] !== 8'h05 || bytes[1] !== 8'h06
        || bytes[2] !== 8'h07 || bytes[3] !== 8'h08)
      $fatal(1, "dynamic source to fixed-array cast");

    reverse_bytes = rev_b4_t'(32'h01020304);
    if (reverse_bytes[3] !== 8'h01 || reverse_bytes[2] !== 8'h02
        || reverse_bytes[1] !== 8'h03 || reverse_bytes[0] !== 8'h04)
      $fatal(1, "descending fixed-array destination order");
    packed_value = logic32_t'(reverse_bytes);
    if (packed_value !== 32'h01020304)
      $fatal(1, "descending fixed-array source order: %08h", packed_value);

    matrix = matrix_t'(32'h11223344);
    if (matrix[1][0] !== 8'h11 || matrix[1][1] !== 8'h22
        || matrix[0][0] !== 8'h33 || matrix[0][1] !== 8'h44)
      $fatal(1, "nested fixed-array destination order");
    packed_value = logic32_t'(matrix);
    if (packed_value !== 32'h11223344)
      $fatal(1, "nested fixed-array source order: %08h", packed_value);

    logic_bytes = l4_t'(32'h01xz0304);
    if (logic_bytes[0] !== 8'h01 || logic_bytes[1] !== 8'hxz
        || logic_bytes[2] !== 8'h03 || logic_bytes[3] !== 8'h04)
      $fatal(1, "four-state fixed-array destination conversion");
    packed_value = logic32_t'(logic_bytes);
    if (packed_value !== 32'h01xz0304)
      $fatal(1, "four-state fixed-array source conversion: %08h",
             packed_value);

    two_state_bytes = b4_t'(32'h01xz0304);
    if (two_state_bytes[0] !== 8'h01 || two_state_bytes[1] !== 8'h00
        || two_state_bytes[2] !== 8'h03 || two_state_bytes[3] !== 8'h04)
      $fatal(1, "two-state fixed-array destination conversion");

    $display("PASS issue747 fixed unpacked bit-stream casts");
  end
endmodule
