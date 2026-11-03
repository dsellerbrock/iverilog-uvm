// IEEE 1800-2017/2023 6.24.3: fixed unpacked arrays and unpacked structs
// participate in explicit bit-stream casts in declaration order.
module sv_bitstream_fixed_uarray_cast;
  typedef byte b4_t[4];
  typedef byte nested_t[1:0][0:1];
  typedef bit [7:0] bits_t[3:0];
  typedef struct { byte a; logic [7:0] b; } pair_t;

  b4_t bytes;
  nested_t nested;
  bits_t bits;
  pair_t pair_value;
  logic [31:0] source;
  int value;
  shortint pair_bits;
  int calls;

  function automatic logic [31:0] next_value;
    calls++;
    return 32'h01020304;
  endfunction

  initial begin
    source = 32'h01020304;
    bytes = b4_t'(source);
    if (bytes[0] !== 8'h01 || bytes[1] !== 8'h02
	|| bytes[2] !== 8'h03 || bytes[3] !== 8'h04)
      $fatal(1, "array cast order/value mismatch: %h %h %h %h",
	     bytes[0], bytes[1], bytes[2], bytes[3]);
    value = int'(bytes);
    if (value !== source)
      $fatal(1, "packed cast value mismatch: %h", value);

    nested = nested_t'(source);
    if (nested[1][0] !== 8'h01 || nested[1][1] !== 8'h02
	|| nested[0][0] !== 8'h03 || nested[0][1] !== 8'h04)
      $fatal(1, "nested array cast order/value mismatch: %h %h %h %h",
	     nested[1][0], nested[1][1], nested[0][0], nested[0][1]);
    value = int'(nested);
    if (value !== source)
      $fatal(1, "nested packed cast value mismatch: %h", value);

    source = 32'h12xz5678;
    bits = bits_t'(source);
    if (bits[3] !== 8'h12 || bits[2] !== 8'h00
	|| bits[1] !== 8'h56 || bits[0] !== 8'h78)
      $fatal(1, "two-state array cast mismatch: %h %h %h %h",
	     bits[3], bits[2], bits[1], bits[0]);

    pair_value.a = 8'h12;
    pair_value.b = 8'h34;
    pair_bits = shortint'(pair_value);
    if (pair_bits !== 16'h1234)
      $fatal(1, "unpacked struct cast mismatch: %h", pair_bits);

    calls = 0;
    nested = nested_t'(next_value());
    if (calls != 1)
      $fatal(1, "source expression evaluated %0d times", calls);

    $display("PASS fixed unpacked-array bit-stream casts");
  end
endmodule
