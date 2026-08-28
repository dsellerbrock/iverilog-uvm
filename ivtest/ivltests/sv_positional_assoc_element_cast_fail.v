// A positional-container cast cannot erase associative-array element index
// metadata. Typed-index and wildcard-index differences are both mismatches.
typedef int cast_assoc_string_inner_t[string];
typedef int cast_assoc_int_inner_t[int];
typedef int cast_assoc_wild_inner_t[*];
typedef cast_assoc_string_inner_t cast_assoc_string_queue_t[$];
typedef cast_assoc_int_inner_t cast_assoc_int_queue_t[$];
typedef cast_assoc_int_inner_t cast_assoc_int_darray_t[];
typedef cast_assoc_wild_inner_t cast_assoc_wild_darray_t[];

module sv_positional_assoc_element_cast_fail;
  cast_assoc_string_inner_t string_result;
  cast_assoc_int_inner_t int_result;
  cast_assoc_int_darray_t int_source;
  cast_assoc_wild_darray_t wildcard_source;

  initial begin
    string_result = cast_assoc_string_queue_t'(int_source).pop_front();
    int_result = cast_assoc_int_queue_t'(wildcard_source).pop_front();
  end
endmodule
