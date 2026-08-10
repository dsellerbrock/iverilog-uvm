// Exact outer-map compatibility recursively includes an associative element's
// own key type.
module sv_assoc_nested_type_fail;
  typedef int inner_string_t[string];
  typedef int inner_int_t[int];
  typedef inner_string_t outer_string_t[string];
  typedef inner_int_t outer_int_t[string];
  outer_string_t target;
  outer_int_t source;

  initial target = source;
endmodule
