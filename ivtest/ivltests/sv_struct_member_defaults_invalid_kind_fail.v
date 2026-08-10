module sv_struct_member_defaults_invalid_kind_fail;
  typedef struct packed {
    logic [3:0] value = 4'ha;
  } packed_defaults_t;

  typedef union {
    integer as_integer = 7;
    logic [31:0] as_bits;
  } union_defaults_t;

  typedef struct {
    packed_defaults_t nested;
  } packed_wrapper_t;

  typedef struct {
    union_defaults_t nested;
  } union_wrapper_t;

  packed_defaults_t packed_value;
  union_defaults_t union_value;
  packed_wrapper_t nested_packed_value;
  union_wrapper_t nested_union_value;
endmodule
