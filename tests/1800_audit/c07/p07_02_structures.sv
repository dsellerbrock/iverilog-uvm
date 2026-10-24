module test;
  typedef struct packed unsigned {
    logic [7:0] high;
    logic [7:0] low;
  } packed_t;

  typedef struct packed signed {
    logic [3:0] high;
    logic [3:0] low;
  } signed_packed_t;

  typedef struct {
    int id;
    string name;
    logic [3:0] flags;
  } unpacked_t;

  packed_t packed_value, packed_copy;
  signed_packed_t signed_value;
  unpacked_t unpacked_value, unpacked_copy;

  initial begin
    packed_value.high = 8'ha5;
    packed_value.low = 8'h5a;
    packed_copy = packed_value;
    if (packed_value !== 16'ha55a || packed_value[15:8] !== 8'ha5
        || packed_value[7:0] !== 8'h5a || packed_copy !== packed_value)
      $fatal(1, "packed structure member, vector, slice, or copy mismatch");

    signed_value.high = 4'hf;
    signed_value.low = 4'hf;
    if ($signed(signed_value) !== -8'sd1)
      $fatal(1, "signed packed structure did not sign-extend as a vector");

    unpacked_value.id = 101;
    unpacked_value.name = "alpha";
    unpacked_value.flags = 4'b1010;
    unpacked_copy = unpacked_value;
    if (unpacked_copy.id != 101 || unpacked_copy.name != "alpha"
        || unpacked_copy.flags != 4'b1010)
      $fatal(1, "unpacked structure member or whole-structure copy mismatch");

    $display("PASS §7.2 packed/unpacked structure checks");
    $finish;
  end
endmodule
