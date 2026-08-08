// Partial-index subarray assignment requires equivalent element types even
// when the packed widths happen to match (IEEE 1800-2017 7.6).
module logic_from_bit;
  logic [7:0] dst [2];
  bit   [7:0] src [2][2];
  always_comb dst = src[0];
endmodule

module signed_from_unsigned;
  logic signed [7:0] dst [2][2];
  logic        [7:0] src [2];
  assign dst[0] = src;
endmodule

module distinct_enum_types;
  typedef enum logic [1:0] {A0, A1} a_t;
  typedef enum logic [1:0] {B0, B1} b_t;
  a_t dst [2];
  b_t src [2][2];
  always_comb dst = src[0];
endmodule

module residual_size_mismatch_rhs;
  logic [7:0] dst [2];
  logic [7:0] src [2][3];
  always_comb dst = src[0];
endmodule

module residual_size_mismatch_lhs;
  logic [7:0] dst [2][2];
  logic [7:0] src [3];
  assign dst[0] = src;
endmodule
