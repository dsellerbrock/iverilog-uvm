// Array-locator results retain their concrete queue element type.
module wrong_queue_element;
  int values[];
  string wrong[$];

  initial wrong = values.min;
endmodule

module wrong_fixed_element;
  int values[];
  string wrong[1];

  initial wrong = values.max;
endmodule

module associative_destination;
  int values[];
  int wrong[string];

  initial wrong = values.min;
endmodule
