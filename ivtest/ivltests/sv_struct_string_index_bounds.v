// IEEE 1800-2017/2023 6.16: out-of-range character reads return zero.
module sv_struct_string_index_bounds;
  typedef struct { string val; } row_t;
  row_t row;
  integer idx;
  bit [1:0] narrow;
  bit signed [1:0] negative;
  bit [63:0] wide;
  initial begin
    row.val = "abc";
    if (row.val[-1] !== 0 || row.val[3] !== 0) $fatal(1, "constant bounds");
    idx = -1;
    if (row.val[idx] !== 0) $fatal(1, "negative variable index");
    idx = 3;
    if (row.val[idx] !== 0) $fatal(1, "length variable index");
    idx = 2147483647;
    if (row.val[idx] !== 0) $fatal(1, "large index");
    row.val = "";
    idx = 0;
    if (row.val[0] !== 0 || row.val[idx] !== 0) $fatal(1, "empty string");
    row.val = "abcde";
    idx = 32'b0000000000000000000000000000001x;
    if (row.val[idx] !== "c") $fatal(1, "partial X index conversion");
    idx = 32'b0000000000000000000000000000001z;
    if (row.val[idx] !== "c") $fatal(1, "partial Z index conversion");
    if (row.val[64'h1_00000001] !== "b") $fatal(1, "int index truncation");
    narrow = 2;
    if (row.val[narrow] !== "c") $fatal(1, "narrow unsigned index");
    negative = -1;
    if (row.val[negative] !== 0) $fatal(1, "narrow signed index");
    wide = 64'h1_00000001;
    if (row.val[wide] !== "b") $fatal(1, "wide variable truncation");
    row.val = "ok";
    if (row.val[1] !== "k") $fatal(1, "read after invalid index");
    $display("PASSED");
  end
endmodule
