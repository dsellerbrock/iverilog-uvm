// An associative map object is not a dynamic array.
module sv_assoc_to_darray_fail;
  typedef int assoc_t[string];
  assoc_t source;
  int target[];

  initial target = source;
endmodule
