module sv_assoc_real_index_type_fail;
  int real_indexed[real];
  int shortreal_indexed[shortreal];
  typedef struct { int i; real r; } real_member_key_t;
  typedef struct { int i; shortreal r; } shortreal_member_key_t;
  int member_indexed[real_member_key_t];
  int shortreal_member_indexed[shortreal_member_key_t];
endmodule
