// IEEE 1800-2017/2023 7.9.8: the argument shall be assignment compatible with
// the index type; an int index is not assignment compatible with an enum.
module issue1222_assoc_traversal_enum_ref_fail;
  typedef enum {A, B} e_t;
  int vals[int];
  e_t k;
  initial void'(vals.first(k));
endmodule
