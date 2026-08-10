package enum_class_forward_kind_pkg;
  typedef class wrong_kind_t;

  typedef enum int {
    WRONG_KIND_IDLE = 0
  } wrong_kind_t;

  class holder;
    // This is the sole use of wrong_kind_t. Class-property type repair must
    // retain the forward typedef's class-vs-enum validation.
    wrong_kind_t state = WRONG_KIND_IDLE;
  endclass
endpackage

module sv_enum_class_typedef_forward_kind_fail;
  import enum_class_forward_kind_pkg::*;
  holder value;
endmodule
