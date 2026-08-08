// IEEE 1800-2017 6.19.3/11.5: selecting bits of an enum produces a
// packed-vector l-value. This remains true when the select happens to span
// the enum's entire width; only assignment to the unselected enum object
// requires enum-compatible typing or an explicit cast.
module sv_enum_full_width_lval_select;
  typedef enum logic [3:0] {
    E_ZERO = 4'h0,
    E_FIVE = 4'h5,
    E_TEN  = 4'ha
  } e_t;
  typedef enum logic [0:0] {
    BIT_ZERO = 1'b0,
    BIT_ONE  = 1'b1
  } bit_e;

  logic [3:0] bits = 4'hd;
  e_t enum_source = E_FIVE;

  e_t continuous_full;
  e_t continuous_indexed_up;
  e_t continuous_indexed_down;
  bit_e continuous_bit;
  e_t [0:0] packed_element;
  e_t [0:0] packed_element_bits;
  e_t unpacked_element [0:0];
  struct packed { e_t value; } record_bits;
  struct packed { e_t value; } record_enum;

  e_t procedural_full;
  e_t procedural_indexed_up;
  e_t procedural_indexed_down;
  e_t nonblocking_full;
  e_t nonblocking_indexed;
  bit_e procedural_bit;
  int errors = 0;

  // Continuous l-value path, including Caliptra's exact enum[3:0] shape.
  assign continuous_full[3:0] = bits;
  assign continuous_indexed_up[0 +: 4] = 4'hc;
  assign continuous_indexed_down[3 -: 4] = 4'h9;
  assign continuous_bit[0] = 1'b1;
  assign packed_element[0] = enum_source;
  assign packed_element_bits[0][3:0] = bits;
  assign unpacked_element[0] = enum_source;
  assign record_bits.value[3:0] = bits;
  assign record_enum.value = enum_source;

  initial begin
    nonblocking_full[3:0] <= 4'hb;
    nonblocking_indexed[0 +: 4] <= 4'he;
    #1;
    if (continuous_full !== 4'hd) begin
      $display("FAIL continuous full select: %h", continuous_full);
      errors++;
    end
    if (continuous_indexed_up !== 4'hc
        || continuous_indexed_down !== 4'h9) begin
      $display("FAIL continuous indexed full selects: up=%h down=%h",
               continuous_indexed_up, continuous_indexed_down);
      errors++;
    end
    if (continuous_bit !== 1'b1) begin
      $display("FAIL continuous one-bit select: %b", continuous_bit);
      errors++;
    end
    if (nonblocking_full !== 4'hb) begin
      $display("FAIL nonblocking full select: %h", nonblocking_full);
      errors++;
    end
    if (nonblocking_indexed !== 4'he) begin
      $display("FAIL nonblocking indexed full select: %h",
               nonblocking_indexed);
      errors++;
    end
    if (packed_element[0] !== E_FIVE
        || unpacked_element[0] !== E_FIVE
        || record_enum.value !== E_FIVE) begin
      $display("FAIL exact enum element/member typing");
      errors++;
    end
    if (packed_element_bits[0] !== 4'hd
        || record_bits.value !== 4'hd) begin
      $display("FAIL enum element/member full select typing");
      errors++;
    end

    // Procedural l-value path: full, narrow, and one-bit selections.
    procedural_full[3:0] = 4'h5;
    procedural_full[1:0] = 2'b10;
    procedural_full[0] = 1'b1;
    procedural_bit[0] = 1'b1;
    procedural_indexed_up[0 +: 4] = 4'h6;
    procedural_indexed_down[3 -: 4] = 4'h3;
    if (procedural_full !== 4'h7 || procedural_bit !== 1'b1) begin
      $display("FAIL procedural selections: full=%h bit=%b",
               procedural_full, procedural_bit);
      errors++;
    end
    if (procedural_indexed_up !== 4'h6
        || procedural_indexed_down !== 4'h3) begin
      $display("FAIL procedural indexed full selects: up=%h down=%h",
               procedural_indexed_up, procedural_indexed_down);
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED: %0d errors", errors);
  end
endmodule
