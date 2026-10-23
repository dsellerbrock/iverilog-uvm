// IEEE 1800-2017/2023 20.7: a fixed-size variable may be queried in a
// constant expression, including a packed dimension after an unpacked one.
module sv_array_query_const_var;
  typedef logic [16:1] Word;
  Word Ram[0:9];

  localparam int UNPACKED_SIZE = $size(Ram);
  localparam int PACKED_SIZE = $size(Ram, 2);
  localparam int PACKED_LEFT = $left(Ram, 2);
  localparam int PACKED_RIGHT = $right(Ram, 2);
  localparam int PACKED_LOW = $low(Ram, 2);
  localparam int PACKED_HIGH = $high(Ram, 2);
  localparam int PACKED_INCREMENT = $increment(Ram, 2);
  localparam int DIMENSIONS = $dimensions(Ram);
  localparam int UNPACKED_DIMENSIONS = $unpacked_dimensions(Ram);
  logic [PACKED_SIZE-1:0] packed_range;

  initial begin
    if (UNPACKED_SIZE != 10 || PACKED_SIZE != 16
        || PACKED_LEFT != 16 || PACKED_RIGHT != 1
        || PACKED_LOW != 1 || PACKED_HIGH != 16
        || PACKED_INCREMENT != 1 || DIMENSIONS != 2
        || UNPACKED_DIMENSIONS != 1 || $bits(packed_range) != 16)
      $fatal(1, "array query constant mismatch: %0d %0d %0d %0d %0d %0d %0d %0d %0d",
             UNPACKED_SIZE, PACKED_SIZE, PACKED_LEFT, PACKED_RIGHT,
             PACKED_LOW, PACKED_HIGH, PACKED_INCREMENT, DIMENSIONS,
             UNPACKED_DIMENSIONS);
    $display("PASS");
  end
endmodule
