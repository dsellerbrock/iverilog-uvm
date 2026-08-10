module sv_ustruct_member_defaults_nonconstant_fail;
  integer runtime_value = 7;

  class marker;
  endclass

  typedef struct {
    integer value = runtime_value;
  } invalid_t;

  typedef struct {
    marker value = new;
  } invalid_class_t;

  // Instantiation without a whole initializer triggers default validation.
  invalid_t value;
  invalid_class_t class_value;
endmodule
