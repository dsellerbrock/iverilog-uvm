module sv_assoc_find_index_unsupported;
  int values[int];
  int hits[$];
  initial hits = values.find_first_index() with (item > 0);
endmodule
