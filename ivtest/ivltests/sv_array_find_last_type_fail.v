// find_last_index returns a queue of int for a non-associative array;
// assigning that result to a string queue is a type error (7.12.1).
module main;
  int values[$];
  string wrong_type[$];

  initial
    wrong_type = values.find_last_index() with (item > 0);
endmodule

module associative_context;
  int values[$];
  int wrong_type[string];

  initial
    wrong_type = values.find_last() with (item > 0);
endmodule
