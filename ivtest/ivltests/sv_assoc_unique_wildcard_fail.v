// Wildcard-index associative-array unique() is legal, but requires traversal
// that preserves each entry's actual key width. Exercise mixed-width keys so
// this implementation limitation cannot regress into unsafe 32-bit traversal.
module main;
  int values[*];
  int result[$];
  bit [79:0] wide_key;
  initial begin
    wide_key = 80'h1234_5678_9abc_def0_1234;
    values[8'h11] = 4;
    values[wide_key] = 5;
    result = values.unique;
    result = values.unique(value) with (value & 1);
  end
endmodule
