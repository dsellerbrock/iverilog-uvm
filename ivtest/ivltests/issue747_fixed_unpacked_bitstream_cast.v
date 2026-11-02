// IEEE 1800-2017/2023 6.24.3: fixed unpacked arrays participate in
// bit-stream casts, with the first declared array element in the MSBs.
module issue747_fixed_unpacked_bitstream_cast;
  typedef byte bytes_t [4];
  typedef byte descending_bytes_t [3:0];
  typedef byte matrix_t [2][2];
  typedef logic [31:0] word_t;
  typedef logic [15:0] halfword_t;
  typedef logic [7:0] logic_bytes_t [4];
  typedef bit [7:0] bit_bytes_t [4];
  typedef struct {
    logic [3:0] upper;
    bit [3:0] lower;
  } mixed_t;
  typedef mixed_t mixed_array_t [2];

  bytes_t bytes;
  descending_bytes_t descending;
  matrix_t matrix;
  logic_bytes_t logic_bytes;
  bit_bytes_t bit_bytes;
  mixed_array_t mixed;
  int packed_value;
  logic [31:0] four_state_value;
  int function_calls;

  function logic [31:0] make_word();
    function_calls++;
    return 32'h11223344;
  endfunction

  initial begin
    bytes = bytes_t'(32'h01020304);
    if (bytes[0] !== 8'h01 || bytes[1] !== 8'h02
        || bytes[2] !== 8'h03 || bytes[3] !== 8'h04)
      $fatal(1, "packed to ascending array: %p", bytes);
    packed_value = int'(bytes);
    if (packed_value !== 32'h01020304)
      $fatal(1, "ascending array to packed: %08x", packed_value);

    descending = descending_bytes_t'(32'h01020304);
    if (descending[3] !== 8'h01 || descending[2] !== 8'h02
        || descending[1] !== 8'h03 || descending[0] !== 8'h04)
      $fatal(1, "packed to descending array: %p", descending);
    packed_value = int'(descending);
    if (packed_value !== 32'h01020304)
      $fatal(1, "descending array to packed: %08x", packed_value);

    matrix = matrix_t'(32'h05060708);
    if (matrix[0][0] !== 8'h05 || matrix[0][1] !== 8'h06
        || matrix[1][0] !== 8'h07 || matrix[1][1] !== 8'h08)
      $fatal(1, "packed to nested array: %p", matrix);
    packed_value = int'(matrix);
    if (packed_value !== 32'h05060708)
      $fatal(1, "nested array to packed: %08x", packed_value);

    logic_bytes = logic_bytes_t'(32'h12x45678);
    four_state_value = word_t'(logic_bytes);
    if (four_state_value !== 32'h12x45678)
      $fatal(1, "four-state array round trip: %h", four_state_value);

    bit_bytes = bit_bytes_t'(32'h12x45678);
    if (bit_bytes[0] !== 8'h12 || bit_bytes[1] !== 8'h04
        || bit_bytes[2] !== 8'h56 || bit_bytes[3] !== 8'h78)
      $fatal(1, "four-state to two-state array conversion: %p", bit_bytes);

    mixed[0].upper = 4'h1;
    mixed[0].lower = 4'h2;
    mixed[1].upper = 4'hx;
    mixed[1].lower = 4'h4;
    four_state_value = halfword_t'(mixed);
    if (four_state_value[15:0] !== 16'h12x4)
      $fatal(1, "mixed aggregate array to packed: %h", four_state_value);

    bytes = bytes_t'(make_word());
    if (function_calls != 1 || bytes[0] !== 8'h11 || bytes[3] !== 8'h44)
      $fatal(1, "packed operand evaluation count/value: %0d %p",
             function_calls, bytes);

    $display("PASSED");
  end
endmodule
