module assoc_find_index_reducer;
  int values[bit [7:0]];
  bit [7:0] hits[$];

  initial begin
    values[8'h20] = 3;
    values[8'h03] = -1;
    values[8'h10] = 2;
    hits = values.find_index() with (item > 0);
    if (hits.size() != 2 || hits[0] !== 8'h10 || hits[1] !== 8'h20)
      $fatal(1, "find_index must return matching associative keys in index order");
    $display("ASSOC_FIND_INDEX_PASS");
  end
endmodule
