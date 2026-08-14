typedef struct packed {
  logic [WIDTH_A-1:0] address;
  logic [WIDTH_D-1:0] data;
  logic [WIDTH_E-1:0] ecc;
  logic [WIDTH_M-1:0] mask;
} unused_invalid_width_t;

module sv_typedef_eager_invalid_width_fail;
endmodule
