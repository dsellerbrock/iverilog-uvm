// Array locator methods require a with clause, and their optional argument
// must be a single iterator identifier (IEEE 1800-2017 7.12.1).
module missing_with;
  int values[$];
  int found[$];

  initial
    found = values.find_last();
endmodule

module invalid_iterator;
  int values[$];
  int indexes[$];

  initial
    indexes = values.find_last_index(1) with (item > 0);
endmodule

module invalid_named_iterator;
  int values[$];
  int indexes[$];

  initial
    indexes = values.find_last_index(.candidate(item)) with (item > 0);
endmodule
