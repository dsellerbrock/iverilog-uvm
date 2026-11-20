typedef struct packed { logic [1:0] data; } pair_t;

module source(output wire [0:3] packed_out, output wire [1:0] both_out [0:1],
              output wire [4:3][-1:0] mixed_out [-2:-1][5:3],
              output wire bit_out [-1:-1], output wire pair_t [1:0] typed_out);
  assign packed_out = 4'b1010;
  assign both_out[0] = 2'b01;
  assign both_out[1] = 2'b10;
  assign mixed_out[-2][5] = 4'b1010;
  assign mixed_out[-2][4] = 4'b0110;
  assign mixed_out[-2][3] = 4'b1001;
  assign mixed_out[-1][5] = 4'b0011;
  assign mixed_out[-1][4] = 4'b1xz0;
  assign mixed_out[-1][3] = 4'bz01x;
  assign bit_out[-1] = 1;
  assign typed_out = 4'b1011;
endmodule

module sink(input wire [4:3][-1:0] whole [-2:-1][5:3]);
  wire plain_wire = 1'b1;
  wire [4:2] plain_vector = 3'b101;
  wire [2:1] plain_array [4:5];
  assign plain_array[4] = 2'b01;
  assign plain_array[5] = 2'b10;
endmodule

module top;
  interconnect [3:0] packed_link;
  interconnect [1:0] both_link [0:1];
  interconnect [4:3][-1:0] mixed_link [-2:-1][5:3];
  interconnect bit_link [-1:-1];
  interconnect [1:0][1:0] typed_link;
  // This whole-array output connection shares the word nexuses.
  source src[0:0](packed_link, both_link, mixed_link, bit_link, typed_link);
  sink dst(mixed_link);
  initial #1 $probe_arrays;
endmodule
