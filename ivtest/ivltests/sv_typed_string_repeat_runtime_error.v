// IEEE 1800-2017/2023 11.4.12.2: a variable string-replication multiplier
// is evaluated at runtime. Invalid runtime values are diagnosed instead of
// becoming a huge allocation or silently producing an unrelated value.
module sv_typed_string_repeat_runtime_error;
  int signed_count;
  logic [31:0] unknown_count;
  logic [64:0] overflowing_count;
  logic signed [65:0] signed_overflowing_count;
  logic [63:0] unsigned_high_count;
  string value;
  int errors;

  initial begin
    signed_count = -1;
    value = {signed_count{"x"}};
    if (value != "") errors++;

    unknown_count = 'x;
    value = {unknown_count{"x"}};
    if (value != "") errors++;

    overflowing_count = {1'b1, 64'b0};
    value = {overflowing_count{"x"}};
    if (value != "") errors++;

    // A direct signed signal must use the same overflow-aware conversion as
    // an expression. The optimized signed signal load historically truncated
    // this value to 2 and repeated twice.
    signed_overflowing_count = 66'h1_0000_0000_0000_0002;
    value = {signed_overflowing_count{"x"}};
    if (value != "") errors++;

    // Bit 63 does not make an unsigned multiplier negative. An empty unit
    // also makes the result empty without attempting an allocation.
    unsigned_high_count = 64'h8000_0000_0000_0000;
    value = {unsigned_high_count{""}};
    if (value != "") errors++;

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
