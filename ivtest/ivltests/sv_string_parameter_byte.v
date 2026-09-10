// IEEE 1800-2017/2023 6.16: typed string parameters select bytes from the left.
module sv_string_parameter_byte;
  localparam string TEXT = "\200A\377";
  localparam string EMPTY = "";
  localparam int FIRST = TEXT[0], MIDDLE = TEXT[1], LAST = TEXT[2];
  localparam int BEFORE = TEXT[-1], AFTER = TEXT[3], NONE = EMPTY[0];
  localparam PACKED_TEXT = "A";
  integer idx, actual;
  initial begin
    if (FIRST !== -128 || MIDDLE !== 65 || LAST !== -1)
      $fatal(1, "constant character values");
    if (BEFORE !== 0 || AFTER !== 0 || NONE !== 0)
      $fatal(1, "constant bounds");
    if ($bits(TEXT[0]) != 8 || $bits(PACKED_TEXT[0]) != 1 || PACKED_TEXT[0] !== 1'b1)
      $fatal(1, "typed byte and untyped packed bit");
    idx = 0; actual = TEXT[idx];
    if (actual !== -128 || actual !== TEXT.getc(idx)) $fatal(1, "variable first");
    idx = 1; actual = TEXT[idx];
    if (actual !== 65) $fatal(1, "variable middle");
    idx = 2; actual = TEXT[idx];
    if (actual !== -1) $fatal(1, "variable last");
    idx = -1;
    if (TEXT[idx] !== 0) $fatal(1, "variable negative");
    idx = 3;
    if (TEXT[idx] !== 0 || EMPTY[0] !== 0) $fatal(1, "variable after");
    $display("PASSED");
  end
endmodule
