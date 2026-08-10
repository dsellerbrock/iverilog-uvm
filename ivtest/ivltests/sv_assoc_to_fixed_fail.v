// A whole associative map cannot be copied into a fixed unpacked array.
module sv_assoc_to_fixed_fail;
  typedef int assoc_t[string];
  assoc_t source;
  int target[2];

  initial target = source;
endmodule
