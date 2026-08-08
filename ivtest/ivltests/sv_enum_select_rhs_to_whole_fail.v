// A bit/part-select of an enum is an integral packed-vector expression, not
// an enum expression, even when the select spans the enum's entire width.
module sv_enum_select_rhs_to_whole_fail;
  typedef enum logic [3:0] { E_ZERO = 4'h0, E_ONE = 4'h1 } e_t;
  e_t source;
  e_t destination;
  assign destination = source[3:0];
endmodule
