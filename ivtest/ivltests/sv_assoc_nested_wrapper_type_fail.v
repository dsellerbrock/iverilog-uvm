// Ordinary container wrappers do not erase a nested associative key type.
module sv_assoc_nested_wrapper_type_fail;
  typedef int inner_string_t[string];
  typedef int inner_int_t[int];
  typedef inner_string_t queue_string_t[$];
  typedef inner_int_t queue_int_t[$];
  typedef struct { inner_string_t values; } struct_string_t;
  typedef struct { inner_int_t values; } struct_int_t;
  queue_string_t target;
  queue_int_t source;
  struct_string_t struct_target;
  struct_int_t struct_source;

  initial begin
    target = source;
    struct_target = struct_string_t'(struct_source);
  end
endmodule
