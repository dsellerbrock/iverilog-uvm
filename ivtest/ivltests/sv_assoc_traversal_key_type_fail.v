module test;
  string map[byte];
  string wrong_key;
  int rc;

  initial begin
    // first/last/next/prev use a ref index argument, which "shall be
    // assignment compatible with the index type" (IEEE 7.9.8); a string
    // is not assignment compatible with a byte index.
    rc = map.first(wrong_key);
    rc = map.last(wrong_key);
    rc = map.next(wrong_key);
    rc = map.prev(wrong_key);
  end
endmodule
