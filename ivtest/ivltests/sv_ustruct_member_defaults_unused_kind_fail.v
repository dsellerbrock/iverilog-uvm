module sv_ustruct_member_defaults_unused_kind_fail;
  // Neither type is consumed by a variable. The declarations themselves are
  // nevertheless illegal under IEEE 1800-2017 7.2.2.
  typedef struct packed {
    integer value = 1;
  } unused_packed_t;

  typedef union {
    integer value = 2;
    logic [31:0] bits;
  } unused_union_t;
endmodule
