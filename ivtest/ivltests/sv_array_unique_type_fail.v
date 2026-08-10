// Array-locator results retain their concrete queue element/index type.
module wrong_unique_queue_element;
  int values[];
  string wrong[$];

  initial wrong = values.unique;
endmodule

module wrong_unique_index_queue_element;
  int values[];
  string wrong[$];

  initial wrong = values.unique_index;
endmodule

module wrong_fixed_element;
  int values[];
  string wrong[3];

  initial wrong = values.unique;
endmodule

module associative_destination;
  int values[];
  int wrong[string];

  initial wrong = values.unique_index;
endmodule
