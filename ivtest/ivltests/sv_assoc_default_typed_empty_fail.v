// An empty pattern retains the explicit cast type that shaped it.
module sv_assoc_default_typed_empty_fail;
  typedef int int_by_string_t[string];
  typedef string string_by_string_t[string];
  int_by_string_t value;

  initial value = string_by_string_t'{};
endmodule
