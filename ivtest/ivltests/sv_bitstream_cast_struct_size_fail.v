// IEEE 1800-2017/2023 6.24.3: fixed-size unpacked and packed bit-stream
// types of different sizes cannot be cast.
typedef struct { byte members[2]; bit tag; } destination_t;
module test;
  logic [15:0] s; destination_t d = destination_t'(s);
  initial $display("%0d", d.tag);
endmodule
