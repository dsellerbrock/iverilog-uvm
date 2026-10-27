module test;
  typedef union packed {
    logic [15:0] word;
    struct packed {
      logic [7:0] high;
      logic [7:0] low;
    } bytes;
  } packed_union_t;

  typedef union {
    int number;
    logic [31:0] bits;
  } unpacked_union_t;

  packed_union_t packed_value;
  unpacked_union_t unpacked_value, unpacked_copy;

  initial begin
    packed_value.word = 16'h1234;
    if (packed_value.bytes.high !== 8'h12
        || packed_value.bytes.low !== 8'h34
        || packed_value[15:0] !== 16'h1234)
      $fatal(1, "packed union overlay or vector-select mismatch");

    unpacked_value.number = 123456;
    unpacked_copy = unpacked_value;
    if (unpacked_copy.number != 123456)
      $fatal(1, "unpacked union active member or whole-union copy mismatch");

    $display("PASS §7.3 untagged union checks");
    $finish;
  end
endmodule
