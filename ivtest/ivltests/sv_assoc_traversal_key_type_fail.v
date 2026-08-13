module test;
  string map[byte];
  int wrong_key;
  int rc;

  initial begin
    // first/last/next/prev use a ref index argument. Its type must be
    // equivalent to the associative array's declared byte index type;
    // assignment conversion is not permitted at this boundary.
    rc = map.first(wrong_key);
    rc = map.last(wrong_key);
    rc = map.next(wrong_key);
    rc = map.prev(wrong_key);
  end
endmodule
