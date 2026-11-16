// $bits of packed unions, structs and arrays without unions stays legal.
module top;
  typedef union packed { bit [7:0] a; bit [7:0] b; } pu_t;
  typedef struct { int x; byte y; } st_t;
  pu_t p; st_t s; int arr[3]; st_t sa[2];
  initial $display("%0d %0d %0d %0d %0d", $bits(p), $bits(pu_t), $bits(s), $bits(arr), $bits(sa));
endmodule
