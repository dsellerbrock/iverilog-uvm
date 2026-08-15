// IEEE 1800-2017 18.4 permits member rand/randc qualifiers only in an
// unpacked structure.  Packed structures and unions are strict negatives.
typedef struct packed {
  rand bit packed_member;
} bad_random_packed_t;

typedef union {
  randc int union_member;
  int ordinary_member;
} bad_random_union_t;

typedef struct {
  rand real real_member;
  rand string string_member;
} bad_random_scalar_t;

module test;
  // All three typedefs are deliberately unused. Declaration legality must
  // not depend on a later variable forcing lazy type elaboration.
endmodule
