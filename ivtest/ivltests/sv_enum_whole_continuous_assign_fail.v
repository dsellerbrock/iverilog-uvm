// Companion to sv_enum_full_width_lval_select: without an explicit select,
// an integral RHS is not implicitly assignment-compatible with an enum.
module sv_enum_whole_continuous_assign_fail;
  typedef enum logic [3:0] { E_ZERO = 4'h0, E_ONE = 4'h1 } e_t;
  logic [3:0] bits;
  e_t whole_enum;
  assign whole_enum = bits;
endmodule
