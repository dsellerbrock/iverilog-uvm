// Selecting an exact element of a packed array of enums retains the enum type.
// This is not the same operation as selecting bits from that enum element.
module sv_enum_packed_element_integral_assign_fail;
  typedef enum logic [3:0] { E_ZERO = 4'h0, E_ONE = 4'h1 } e_t;
  e_t [0:0] values;
  logic [3:0] bits;
  assign values[0] = bits;
endmodule
