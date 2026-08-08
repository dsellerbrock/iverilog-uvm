// Descending full-width indexed selects also have packed-vector type and
// cannot be assigned to a whole enum without an explicit cast.
module sv_enum_indexed_down_select_rhs_to_whole_fail;
  typedef enum logic [3:0] { E_ZERO = 4'h0, E_ONE = 4'h1 } e_t;
  e_t source;
  e_t destination;
  assign destination = source[3 -: 4];
endmodule
