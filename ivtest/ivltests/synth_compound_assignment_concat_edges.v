`begin_keywords "1800-2012"

module main;
  bit [1:0] x_bit_first_bits;
  logic [2:0] x_bit_first_logic;
  logic [2:0] x_logic_first_logic;
  bit [1:0] x_logic_first_bits;

  logic unequal_hi;
  logic [2:0] unequal_mid;
  logic [4:0] unequal_low;

  logic signed [1:0] shift_signed_hi;
  logic [2:0] shift_unsigned_mid;
  logic signed [1:0] shift_signed_low;

  logic [9:0] disjoint_carrier;
  logic [9:0] overlap_carrier;

  logic many_11;
  logic many_10;
  logic many_9;
  logic many_8;
  logic many_7;
  logic many_6;
  logic many_5;
  logic many_4;
  logic many_3;
  logic many_2;
  logic many_1;
  logic many_0;

  always_comb begin
    // The arithmetic result is four-state before it is split among leaves.
    // An all-X RHS makes the aggregate result X; only the individual bit leaf
    // is converted to zero when that result is split. Exercise both mixed
    // leaf orders and unequal widths.
    x_bit_first_bits = '0;
    x_bit_first_logic = '0;
    {x_bit_first_bits, x_bit_first_logic} += 5'bxxxxx;

    x_logic_first_logic = '0;
    x_logic_first_bits = '0;
    {x_logic_first_logic, x_logic_first_bits} += 5'bxxxxx;

    // Carry across two unequal leaf boundaries.
    {unequal_hi, unequal_mid, unequal_low} = 9'b0_111_11111;
    {unequal_hi, unequal_mid, unequal_low} += 9'b1;

    // A concatenation is unsigned even when some leaves are signed, so >>>
    // must zero-fill the aggregate rather than sign-extend a signed leaf.
    {shift_signed_hi, shift_unsigned_mid, shift_signed_low} = 7'b10_101_11;
    {shift_signed_hi, shift_unsigned_mid, shift_signed_low} >>>= 1;

    // Preserve the carrier bits omitted by two disjoint selects while a carry
    // crosses the concatenation boundary.
    disjoint_carrier = 10'b000_10_01111;
    {disjoint_carrier[9:7], disjoint_carrier[4:0]} += 8'h01;

    // Read overlapping selects from one prior carrier and write a result whose
    // duplicate bits agree, avoiding assignment-order dependence.
    overlap_carrier = 10'b0110010101;
    {overlap_carrier[9:5], overlap_carrier[7:3]} ^= 10'b1100100101;

    // A modest number of leaves catches accidental quadratic/recursive
    // assumptions without making the focused regression expensive.
    {many_11, many_10, many_9, many_8, many_7, many_6,
     many_5, many_4, many_3, many_2, many_1, many_0} = 12'h0ff;
    {many_11, many_10, many_9, many_8, many_7, many_6,
     many_5, many_4, many_3, many_2, many_1, many_0} += 12'h001;
  end

  (* ivl_synthesis_off *)
  initial begin
    #1;

    if ({x_bit_first_bits, x_bit_first_logic} !== 5'b00xxx)
      $fatal(1, "bit-first four-state aggregation: %b %b",
             x_bit_first_bits, x_bit_first_logic);
    if ({x_logic_first_logic, x_logic_first_bits} !== 5'bxxx00)
      $fatal(1, "logic-first four-state aggregation: %b %b",
             x_logic_first_logic, x_logic_first_bits);

    if ({unequal_hi, unequal_mid, unequal_low} !== 9'h100)
      $fatal(1, "unequal-width carry: %b %b %b",
             unequal_hi, unequal_mid, unequal_low);
    if ({shift_signed_hi, shift_unsigned_mid, shift_signed_low}
        !== 7'b0101011)
      $fatal(1, "unsigned concatenation >>>: %b %b %b",
             shift_signed_hi, shift_unsigned_mid, shift_signed_low);

    if (disjoint_carrier !== 10'b0001010000)
      $fatal(1, "disjoint carrier selects: %b", disjoint_carrier);
    if ((overlap_carrier !== 10'b1010111101)
        || ({overlap_carrier[9:5], overlap_carrier[7:3]}
            !== 10'b1010110111))
      $fatal(1, "overlapping carrier selects: %b", overlap_carrier);

    if ({many_11, many_10, many_9, many_8, many_7, many_6,
         many_5, many_4, many_3, many_2, many_1, many_0} !== 12'h100)
      $fatal(1, "many-leaf carry");

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
