// Fixed-array locator methods are legal for arbitrary declared ranges.
// Keep nonzero-base ranges loud until the loop carries a separate declared
// index for item.index and *_index results.
module main;
  int values[5:3];
  int indexes[$];

  initial
    indexes = values.find_last_index with (item > 0);
endmodule
