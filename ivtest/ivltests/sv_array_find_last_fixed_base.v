// Fixed-array locator methods are legal for arbitrary declared ranges
// (IEEE 1800-2017/2023 7.12.1). This nonzero-base declared range used
// to be an unimplemented "sorry" rejection; it is now correctly
// implemented (L36) -- the loop carries a separate declared index for
// item.index and *_index results, computed generically for any base.
module main;
  int values[5:3];
  int indexes[$];

  initial begin
    values[5] = 1;
    values[4] = 2;
    values[3] = 3;
    indexes = values.find_last_index with (item > 0);
    if (indexes.size() == 1 && indexes[0] == 3)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
