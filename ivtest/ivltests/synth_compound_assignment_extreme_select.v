`begin_keywords "1800-2012"

// IEEE 1800-2023 11.5.1 defines a write through a wholly out-of-bounds
// part-select as having no effect. Constant out-of-range indices may also be
// diagnosed at compile time (Note 2), so this is an Icarus no-crash and
// accepted-behavior regression rather than a cross-tool acceptance test.
// In particular, computing the selected interval must not overflow a host
// signed long or cause synthesis to allocate an enormous carrier.
module synth_compound_assignment_extreme_select;
  logic [7:0] mask;
  logic [7:0] result;
  logic [7:0] clipped;
  logic [7:0] boundary;
  logic [7:0] down_direction;
  logic [0:7] up_direction;
  logic [7:0] uint64_result;
  logic [7:0] uint64_concat_result;
  logic [7:0] dynamic_unsigned_result;
  logic [7:0] dynamic_signed_result;
  logic [7:0] narrow_unsigned;
  logic [7:0] narrow_signed;
  logic [3:0] sibling;
  logic [3:0] uint64_sibling;
  logic [64:0] dynamic_unsigned_base;
  logic signed [64:0] dynamic_signed_base;

  always_comb begin
    result = mask;
    result[64'sh7fff_ffff_ffff_ffff +: 2] += 2'b01;
    result[64'sh8000_0000_0000_0000 +: 2] ^= 2'b11;
    result[65'h1_0000_0000_0000_0000 +: 2] += 2'b01;
    result[66'sh3_0000_0000_0000_0000 +: 2] ^= 2'b11;
    result[65'h1_0000_0000_0000_0000] ^= 1'b1;
    result[66'sh3_0000_0000_0000_0000] ^= 1'b1;

    sibling = mask[3:0];
    {sibling, result[65'h1_0000_0000_0000_0000 +: 2]} ^= 6'b10_1011;

    uint64_result = mask;
    uint64_result[64'hffff_ffff_ffff_ffff +: 2] ^= 2'b11;
    uint64_result[64'hffff_ffff_ffff_ffff] ^= 1'b1;
    uint64_concat_result = mask;
    uint64_sibling = mask[3:0];
    {uint64_sibling,
     uint64_concat_result[64'hffff_ffff_ffff_ffff +: 2]} ^= 6'b01_0011;

    clipped = mask;
    clipped[-2 +: 5] ^= 5'b10101;
    clipped[6 +: 5] ^= 5'b10101;

    boundary = mask;
    boundary[-5 +: 5] ^= 5'b11111;
    boundary[-4 +: 5] ^= 5'b10000;
    boundary[8 +: 5] ^= 5'b11111;
    boundary[7 +: 5] ^= 5'b00001;

    down_direction = mask;
    down_direction[2 -: 5] ^= 5'b10110;
    down_direction[5 +: 5] ^= 5'b01101;

    up_direction = mask;
    up_direction[5 +: 5] ^= 5'b10110;
    up_direction[2 -: 5] ^= 5'b01101;

    dynamic_unsigned_result = mask;
    dynamic_unsigned_result[dynamic_unsigned_base +: 2] ^= 2'b11;
    dynamic_signed_result = mask;
    dynamic_signed_result[dynamic_signed_base +: 2] ^= 2'b10;

    narrow_unsigned = '1;
    narrow_unsigned[-2 +: 5] = 1'b1;
    narrow_signed = '0;
    narrow_signed[-2 +: 5] = 1'sb1;
  end

  (* ivl_synthesis_off *)
  initial begin
    dynamic_unsigned_base = 65'h1_0000_0000_0000_0000;
    dynamic_signed_base = 65'sh1_0000_0000_0000_0000;
    mask = 8'h81;
    #1;
    if (result !== 8'h81)
      $fatal(1, "FAILED first result=%h", result);
    if (sibling !== 4'hb)
      $fatal(1, "FAILED first sibling=%h", sibling);
    if (uint64_result !== 8'h81)
      $fatal(1, "FAILED first uint64_result=%h", uint64_result);
    if (uint64_concat_result !== 8'h81)
      $fatal(1, "FAILED first uint64_concat_result=%h", uint64_concat_result);
    if (uint64_sibling !== 4'h5)
      $fatal(1, "FAILED first uint64_sibling=%h", uint64_sibling);
    if (clipped !== 8'hc4)
      $fatal(1, "FAILED first clipped=%h", clipped);
    if (boundary !== 8'h00)
      $fatal(1, "FAILED first boundary=%h", boundary);
    if (down_direction !== 8'h24)
      $fatal(1, "FAILED first down_direction=%h", down_direction);
    if (up_direction !== 8'h24)
      $fatal(1, "FAILED first up_direction=%h", up_direction);
    if (dynamic_unsigned_result !== 8'h81)
      $fatal(1, "FAILED first dynamic_unsigned_result=%h",
             dynamic_unsigned_result);
    if (dynamic_signed_result !== 8'h81)
      $fatal(1, "FAILED first dynamic_signed_result=%h",
             dynamic_signed_result);
    if (narrow_unsigned !== 8'hf8)
      $fatal(1, "FAILED first narrow_unsigned=%h", narrow_unsigned);
    if (narrow_signed !== 8'h07)
      $fatal(1, "FAILED first narrow_signed=%h", narrow_signed);

    dynamic_unsigned_base = 65'h0_ffff_ffff_ffff_ffff;
    dynamic_signed_base = -65'sd1;
    mask = 8'h0c;
    #1;
    if (result !== 8'h0c)
      $fatal(1, "FAILED second result=%h", result);
    if (sibling !== 4'h6)
      $fatal(1, "FAILED second sibling=%h", sibling);
    if (uint64_result !== 8'h0c)
      $fatal(1, "FAILED second uint64_result=%h", uint64_result);
    if (uint64_concat_result !== 8'h0c)
      $fatal(1, "FAILED second uint64_concat_result=%h", uint64_concat_result);
    if (uint64_sibling !== 4'h8)
      $fatal(1, "FAILED second uint64_sibling=%h", uint64_sibling);
    if (clipped !== 8'h49)
      $fatal(1, "FAILED second clipped=%h", clipped);
    if (boundary !== 8'h8d)
      $fatal(1, "FAILED second boundary=%h", boundary);
    if (down_direction !== 8'ha9)
      $fatal(1, "FAILED second down_direction=%h", down_direction);
    if (up_direction !== 8'ha9)
      $fatal(1, "FAILED second up_direction=%h", up_direction);
    if (dynamic_unsigned_result !== 8'h0c)
      $fatal(1, "FAILED second dynamic_unsigned_result=%h",
             dynamic_unsigned_result);
    if (dynamic_signed_result !== 8'h0d)
      $fatal(1, "FAILED second dynamic_signed_result=%h",
             dynamic_signed_result);
    if (narrow_unsigned !== 8'hf8)
      $fatal(1, "FAILED second narrow_unsigned=%h", narrow_unsigned);
    if (narrow_signed !== 8'h07)
      $fatal(1, "FAILED second narrow_signed=%h", narrow_signed);

    $display("PASSED");
  end
endmodule

`end_keywords
