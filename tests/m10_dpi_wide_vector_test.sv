// M10: DPI packed vector marshaling for wide (>64-bit) arguments
// (IEEE 1800-2017 35.5.6). Previously by-value DPI arguments were limited
// to 64 bits (a loud sorry); now 2-state `bit [W-1:0]` arguments marshal
// as svBitVecVal[] and 4-state `logic [W-1:0]` as svLogicVecVal[], passed
// as pointers, for input, output and inout of any width. Here W = 72
// (three 32-bit words).
module m10_dpi_wide_vector_test_top;
  typedef bit [7:0] octet_t;
  typedef octet_t [3:0] nested_packed_t;
  typedef enum bit [7:0] { EV_ZERO = 8'h00, EV_A5 = 8'ha5 }
    vector_enum_t;
  typedef enum int { EA_NEG = -3, EA_POS = 9 } atom_enum_t;
  typedef struct packed {
    bit [7:0] hi;
    bit [7:0] lo;
  } small_struct_t;
  typedef union packed {
    bit [95:0] bits;
    bit [2:0][31:0] words;
  } wide_union_t;

  import "DPI-C" function void wide_xor(input bit [71:0] a,
                                        input bit [71:0] b,
                                        output bit [71:0] c);
  import "DPI-C" function void wide_logic_copy(input  logic [71:0] a,
                                               output logic [71:0] b);
  import "DPI-C" function void wide_logic_invert(input  logic [71:0] a,
                                                 output logic [71:0] b);
  // Packed arrays keep the pointer ABI even when their widths coincide
  // with C integer atoms. These signatures cover the OpenTitan PRESENT
  // case that was previously mis-marshaled as uint64_t/uint32_t by value.
  import "DPI-C" function void packed64_xor(input  bit [63:0] a,
                                             input  bit [63:0] b,
                                             output bit [63:0] c);
  import "DPI-C" function void packed32_logic_copy(input  logic [31:0] a,
                                                    output logic [31:0] b);
  import "DPI-C" function void scalar_vector_shape_copy(
    input bit sb_i, input bit [0:0] vb_i,
    input logic sl_i, input logic [0:0] vl_i,
    output bit sb_o, output bit [0:0] vb_o,
    output logic sl_o, output logic [0:0] vl_o);
  import "DPI-C" function void canonical_atom_copy(
    input integer integer_i, output integer integer_o,
    input time time_i, output time time_o);
  import "DPI-C" function void typedef_enum_copy(
    input nested_packed_t nested_i, output nested_packed_t nested_o,
    input vector_enum_t ve_i, output vector_enum_t ve_o,
    input atom_enum_t ae_i, output atom_enum_t ae_o);
  import "DPI-C" function void packed_aggregate_copy(
    input small_struct_t small_i, output small_struct_t small_o,
    input wide_union_t wide_i, output wide_union_t wide_o);
  import "DPI-C" function chandle make_test_handle(
    input longint unsigned value);
  import "DPI-C" function longint unsigned read_test_handle(
    input chandle value);
  import "DPI-C" function void advance_test_handle(inout chandle value);

  bit   [71:0] a, b, c;
  logic [71:0] la, lb;
  bit scalar_bit_out;
  bit [0:0] vector_bit_out;
  logic scalar_logic_out;
  logic [0:0] vector_logic_out;
  integer integer_i, integer_o;
  time time_i, time_o;
  nested_packed_t nested_i, nested_o;
  vector_enum_t vector_enum_i, vector_enum_o;
  atom_enum_t atom_enum_i, atom_enum_o;
  small_struct_t small_i, small_o;
  wide_union_t wide_i, wide_o;
  chandle handle_value;
  longint unsigned handle_bits;
  int errors = 0;

  initial begin
    // 2-state wide xor (svBitVecVal round trip, output copy-back).
    a = 72'hDEAD_BEEF_1234_5678_9A;
    b = 72'h0F0F_0F0F_0F0F_0F0F_0F;
    wide_xor(a, b, c);
    if (c !== (a ^ b)) begin
      $display("FAIL: wide_xor c=%h exp=%h", c, a ^ b); errors++;
    end

    // 4-state passthrough preserving X/Z (svLogicVecVal round trip).
    la = 72'h1234_5678_9ABC_DEF0_11;
    la[3]  = 1'bx;
    la[70] = 1'bz;
    wide_logic_copy(la, lb);
    if (lb !== la) begin
      $display("FAIL: wide_logic_copy lb=%h exp=%h", lb, la); errors++;
    end

    // 4-state read+write: complement known bits, keep X/Z in place.
    wide_logic_invert(la, lb);
    for (int i = 0; i < 72; i++) begin
      if (la[i] === 1'b0 && lb[i] !== 1'b1) begin
        $display("FAIL: invert bit %0d la=0 lb=%b", i, lb[i]); errors++;
      end
      if (la[i] === 1'b1 && lb[i] !== 1'b0) begin
        $display("FAIL: invert bit %0d la=1 lb=%b", i, lb[i]); errors++;
      end
      if (la[i] === 1'bx && lb[i] !== 1'bx) begin
        $display("FAIL: invert bit %0d la=x lb=%b", i, lb[i]); errors++;
      end
      if (la[i] === 1'bz && lb[i] !== 1'bz) begin
        $display("FAIL: invert bit %0d la=z lb=%b", i, lb[i]); errors++;
      end
    end

    a[63:0] = 64'hDEAD_BEEF_1234_5678;
    b[63:0] = 64'h0F0F_0F0F_F0F0_F0F0;
    packed64_xor(a[63:0], b[63:0], c[63:0]);
    if (c[63:0] !== (a[63:0] ^ b[63:0])) begin
      $display("FAIL: packed64_xor c=%h exp=%h", c[63:0],
               a[63:0] ^ b[63:0]); errors++;
    end

    la[31:0] = 32'h1234_5678;
    la[3] = 1'bx;
    la[30] = 1'bz;
    packed32_logic_copy(la[31:0], lb[31:0]);
    if (lb[31:0] !== la[31:0]) begin
      $display("FAIL: packed32_logic_copy lb=%h exp=%h", lb[31:0],
               la[31:0]); errors++;
    end

    // A scalar and an explicit [0:0] vector have the same SV width but
    // different DPI ABIs (unsigned char versus canonical vector pointer).
    scalar_vector_shape_copy(1'b1, 1'b0, 1'bz, 1'bx,
                             scalar_bit_out, vector_bit_out,
                             scalar_logic_out, vector_logic_out);
    if (scalar_bit_out !== 1'b0 || vector_bit_out !== 1'b1 ||
        scalar_logic_out !== 1'bz || vector_logic_out !== 1'bx) begin
      $display("FAIL: scalar/vector [0:0] DPI shape"); errors++;
    end

    // integer and time are 4-state packed types in Annex H canonical
    // format; X/Z must survive rather than being coerced through int64_t.
    integer_i = 32'h12x4_z678;
    time_i = 64'h1234_5678_9abc_def0;
    time_i[5] = 1'bx;
    time_i[52] = 1'bz;
    canonical_atom_copy(integer_i, integer_o, time_i, time_o);
    if (integer_o !== integer_i || time_o !== time_i) begin
      $display("FAIL: integer/time canonical copy integer=%h/%h time=%h/%h",
               integer_o, integer_i, time_o, time_i); errors++;
    end

    // Typedef-added packed dimensions and a vector-based enum are
    // canonical vectors. An enum based on int retains int's scalar ABI.
    nested_i = 32'h89ab_cdef;
    vector_enum_i = EV_A5;
    atom_enum_i = EA_NEG;
    typedef_enum_copy(nested_i, nested_o, vector_enum_i, vector_enum_o,
                      atom_enum_i, atom_enum_o);
    if (nested_o !== nested_i || vector_enum_o !== vector_enum_i ||
        atom_enum_o !== atom_enum_i) begin
      $display("FAIL: typedef/enum DPI representation"); errors++;
    end

    // Packed structs/unions use the same canonical vector ABI regardless
    // of whether their total width is below or above 64 bits.
    small_i = 16'hc35a;
    wide_i.bits = 96'h0123_4567_89ab_cdef_1357_9bdf;
    packed_aggregate_copy(small_i, small_o, wide_i, wide_o);
    if (small_o !== small_i || wide_o !== wide_i) begin
      $display("FAIL: packed aggregate DPI representation"); errors++;
    end

    // chandle is void*, including return and inout, not uint64_t.
    handle_bits = 64'h0000_0000_0001_2340;
    handle_value = make_test_handle(handle_bits);
    if (read_test_handle(handle_value) !== handle_bits) begin
      $display("FAIL: chandle return/input"); errors++;
    end
    advance_test_handle(handle_value);
    if (read_test_handle(handle_value) !== handle_bits + 64'h10) begin
      $display("FAIL: chandle inout"); errors++;
    end

    if (errors == 0) $display("PASS: m10 dpi wide vector");
    else $display("FAIL: m10 dpi wide vector (%0d errors)", errors);
    $finish(0);
  end
endmodule
