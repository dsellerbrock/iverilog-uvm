// These min/max forms are legal array locators, but their comparison and
// keyed-iteration semantics remain deliberately loud until implemented.
module real_dynamic_receiver;
  real values[];
  real result[$];

  initial result = values.min;
endmodule

module string_dynamic_receiver;
  string values[];
  string result[$];

  initial result = values.max;
endmodule

module associative_receiver;
  int values[string];
  int result[$];

  initial result = values.min;
endmodule
