// IEEE 1800-2017/2023 7.8.5: an index containing x or z in any element is invalid.
module issue426_assoc_struct_key_xz_fail;
  typedef struct {int x; logic [3:0] y;} us_t;
  int m[us_t];
  initial m = '{us_t'{1, 4'bx01z}: 5};
endmodule
