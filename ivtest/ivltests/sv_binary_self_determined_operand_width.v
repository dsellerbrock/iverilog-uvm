// IEEE 1800-2017 11.8.1: a self-determined operand keeps its own width
// internally, then is converted to the enclosing binary expression's common
// type. This is the form used by Caliptra's VeeR configuration parameters.
typedef struct packed {
  logic [8:0] LSU_NUM_NBLOAD;
} el2_param_t;

module sv_binary_self_determined_operand_width #(
  parameter el2_param_t pt = '{LSU_NUM_NBLOAD: 9'd4}
);
  localparam NBLOAD_SIZE_MSB = int'(pt.LSU_NUM_NBLOAD) - 1;

  logic [NBLOAD_SIZE_MSB:0] load_slots;
  logic signed [31:0] signed_value;
  logic        [31:0] unsigned_value;
  logic signed [32:0] signed_result;
  logic signed [32:0] signing_cast_result;
  logic        [32:0] unsigned_result;
  logic        [32:0] sizing_cast_result;
  logic        [32:0] bitwise_result;

  initial begin
    if (NBLOAD_SIZE_MSB != 3 || $bits(load_slots) != 4)
      $fatal(1, "FAILED -- packed-struct parameter expression");

    signed_value = -2;
    unsigned_value = 32'hffff_ffff;

    // The 32-bit type casts are self-determined. The enclosing operators are
    // 33-bit and must sign- or zero-extend the operands using their common
    // signedness before evaluation.
    signed_result = int'(signed_value) - 33'sd3;
    signing_cast_result = signed'(signed_value) - 33'sd3;
    unsigned_result = int'(unsigned_value) + 33'h1_0000_0000;
    sizing_cast_result = 32'(unsigned_value) + 33'h1_0000_0000;
    bitwise_result = int'(unsigned_value) & 33'h1_ffff_ffff;

    if (signed_result !== -33'sd5)
      $fatal(1, "FAILED -- signed subtraction: %h", signed_result);
    if (signing_cast_result !== -33'sd5)
      $fatal(1, "FAILED -- signing cast: %h", signing_cast_result);
    if (unsigned_result !== 33'h1_ffff_ffff)
      $fatal(1, "FAILED -- unsigned addition: %h", unsigned_result);
    if (sizing_cast_result !== 33'h1_ffff_ffff)
      $fatal(1, "FAILED -- sizing cast: %h", sizing_cast_result);
    if (bitwise_result !== 33'h0_ffff_ffff)
      $fatal(1, "FAILED -- unsigned bitwise conversion: %h", bitwise_result);

    $display("PASSED");
  end
endmodule
