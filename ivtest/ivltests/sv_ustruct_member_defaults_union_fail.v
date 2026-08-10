module sv_ustruct_member_defaults_union_fail;
  typedef union {
    integer as_integer;
    logic [31:0] as_bits;
  } choice_t;

  typedef struct {
    integer tag = 1;
    choice_t choice;
  } typedef_union_container_t;
  typedef_union_container_t typedef_union_value;

  typedef struct {
    integer tag = 2;
    union {
      integer as_integer;
      logic [31:0] as_bits;
    } choice;
  } direct_union_container_t;
  direct_union_container_t direct_union_value;
endmodule
