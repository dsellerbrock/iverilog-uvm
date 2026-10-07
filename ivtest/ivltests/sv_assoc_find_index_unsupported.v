module sv_assoc_find_index_unsupported;
  // IEEE 1800-2017/2023 §7.12.1 excludes wildcard-index associative arrays.
  int values[*];
  int hits[$];
  initial hits = values.find_first_index() with (item > 0);
endmodule
