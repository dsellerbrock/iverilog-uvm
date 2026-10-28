typedef union {
  int i;
  byte b;
} U;

typedef struct {
  U value;
} S;

module sv_struct_default_unpacked_union_fail;
  S target;
  initial target = '{default:5};
endmodule
