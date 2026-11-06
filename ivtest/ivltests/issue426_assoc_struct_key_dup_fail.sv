// IEEE 1800-2017/2023 10.9.1: the same index more than once is an error;
// struct indices compare by value (7.8.5).
module issue426_assoc_struct_key_dup_fail;
  typedef struct {int x; logic [3:0] y;} us_t;
  int m[us_t];
  initial m = '{us_t'{1, 4'd2}: 5, us_t'{1, 4'd2}: 6};
endmodule
