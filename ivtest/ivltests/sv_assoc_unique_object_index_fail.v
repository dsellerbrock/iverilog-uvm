module main;
  // IEEE 1800-2017 7.8.5 explicitly includes dynamically sized types as
  // legal associative index types when equality is defined. The current
  // runtime cannot yet compare such value-backed keys during traversal.
  typedef int object_key_t[];
  int values[object_key_t];
  int result[$];
  initial result = values.unique();
endmodule
