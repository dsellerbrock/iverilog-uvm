package enum_class_mismatch_pkg;
  typedef enum int {
    A_IDLE = 0,
    A_BUSY = 1
  } enum_a_t;
  typedef enum int {
    B_IDLE = 0,
    B_BUSY = 1
  } enum_b_t;

  class bad_holder;
    enum_a_t a = A_IDLE;
    enum_b_t b = B_IDLE;

    function enum_a_t bad_return();
      return b;
    endfunction

    function void bad_formal(enum_b_t value);
      a = value;
    endfunction

    function void bad_literal();
      a = B_BUSY;
    endfunction
  endclass
endpackage

module sv_enum_class_typedef_mismatch_fail;
  import enum_class_mismatch_pkg::*;
  bad_holder holder;
endmodule
