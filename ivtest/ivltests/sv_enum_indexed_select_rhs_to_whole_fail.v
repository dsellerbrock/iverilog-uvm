// A full-width indexed select has packed-vector type just like a fixed
// part-select; it is not implicitly assignment-compatible with an enum.
module sv_enum_indexed_select_rhs_to_whole_fail;
  typedef enum logic [3:0] { E_ZERO = 4'h0, E_ONE = 4'h1 } e_t;
  e_t source;
  e_t destination;
  assign destination = source[0 +: 4];
endmodule
