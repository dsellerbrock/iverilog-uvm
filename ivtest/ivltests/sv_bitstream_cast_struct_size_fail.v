// IEEE 1800-2017/2023 6.24.3: fixed-size unpacked and packed bit-stream
// types of different sizes cannot be cast.
module test;
  struct { bit [7:0] a; shortint b; } s;
  int d = int'(s);
  initial $display("%0d", d);
endmodule
