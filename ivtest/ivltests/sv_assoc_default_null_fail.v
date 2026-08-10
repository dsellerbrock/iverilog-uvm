// A literal null is a class-handle value, not an empty associative array.
module sv_assoc_default_null_fail;
  typedef int int_by_string_t[string];
  int_by_string_t value;

  initial value = null;
endmodule
