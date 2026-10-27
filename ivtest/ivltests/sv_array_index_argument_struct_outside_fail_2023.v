// IEEE 1800-2023 7.12.4 iterator-index names are local to the with clause.
module sv_array_index_argument_struct_outside_fail_2023;
  typedef struct { int value; } item_t;
  item_t item;
  int value;

  initial value = item.position;
endmodule
