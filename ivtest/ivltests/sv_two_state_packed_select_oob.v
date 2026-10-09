module sv_two_state_packed_select_oob;
  bit [7:0] down = 8'ha5;
  bit [0:7] up = 8'ha5;
  logic [7:0] four_state = 8'ha5;
  parameter bit [7:0] bit_param = 8'ha5;
  parameter logic [7:0] logic_param = 8'ha5;
  bit [99:0] bits = '1;
  logic [99:0] logics = '1;
  integer index;
  integer base;
  logic bit_oob_logic, bit_x_logic;
  bit bit_oob_bit, bit_x_bit;
  logic four_state_oob, four_state_x;
  logic four_state_const_oob, four_state_const_x;
  bit bit_const_oob, bit_const_x;
  logic [7:0] part_logic, part_constant_logic;
  bit [7:0] part_bit, part_constant_bit;
  logic [7:0] part_indexed_up_logic, part_indexed_down_logic;
  bit [7:0] part_indexed_up_bit, part_indexed_down_bit;
  logic [7:0] param_part_logic;
  bit [7:0] param_part_bit;
  logic [7:0] part_constant_indexed_down_logic;
  bit [7:0] part_constant_indexed_down_bit;
  logic [7:0] four_state_part;
  logic [7:0] part_full_oob_logic;
  bit [7:0] part_full_oob_bit;
  integer failed = 0;

  task automatic check(input string what, input logic [7:0] got,
                       input logic [7:0] expected);
    if (got !== expected) begin
      $display("FAILED: %s got %b expected %b", what, got, expected);
      failed++;
    end
  endtask

  initial begin
    index = 8;
    bit_oob_logic = down[index];
    bit_oob_bit = down[index];
    four_state_oob = four_state[index];
    bit_const_oob = down[8];
    bit_const_x = down[1'bx];
    four_state_const_oob = four_state[8];
    four_state_const_x = four_state[1'bx];
    index = 'x;
    bit_x_logic = down[index];
    bit_x_bit = down[index];
    four_state_x = four_state[index];

    if (bit_oob_logic !== 1'b0 || bit_oob_bit !== 1'b0)
      begin $display("FAILED: two-state out-of-range bit select"); failed++; end
    if (bit_x_logic !== 1'b0 || bit_x_bit !== 1'b0)
      begin $display("FAILED: two-state unknown bit index"); failed++; end
    if (four_state_oob !== 1'bx || four_state_x !== 1'bx)
      begin $display("FAILED: four-state invalid bit select"); failed++; end
    if (bit_const_oob !== 1'b0 || bit_const_x !== 1'b0)
      begin $display("FAILED: two-state constant invalid bit select"); failed++; end
    if (four_state_const_oob !== 1'bx || four_state_const_x !== 1'bx)
      begin $display("FAILED: four-state constant invalid bit select"); failed++; end

    index = 8;
    if (bit_param[index] !== 1'b0 || bit_param[8] !== 1'b0
        || bit_param[1'bx] !== 1'b0
        || logic_param[index] !== 1'bx || logic_param[8] !== 1'bx
        || logic_param[1'bx] !== 1'bx)
      begin $display("FAILED: parameter invalid bit select"); failed++; end

    base = 96;
    part_logic = bits[base +: 8];
    part_bit = bits[base +: 8];
    part_constant_logic = bits[103:96];
    part_constant_bit = bits[103:96];
    part_indexed_up_logic = bits[96 +: 8];
    part_indexed_up_bit = bits[96 +: 8];
    part_full_oob_logic = bits[120 +: 8];
    part_full_oob_bit = bits[120 +: 8];
    four_state_part = logics[base +: 8];
    base = 3;
    part_indexed_down_logic = bits[base -: 8];
    part_indexed_down_bit = bits[base -: 8];
    part_constant_indexed_down_logic = bits[3 -: 8];
    part_constant_indexed_down_bit = bits[3 -: 8];
    check("dynamic part to logic", part_logic, 8'bxxxx1111);
    check("dynamic part to bit", part_bit, 8'b00001111);
    check("constant part to logic", part_constant_logic, 8'bxxxx1111);
    check("constant part to bit", part_constant_bit, 8'b00001111);
    check("constant indexed up part to logic", part_indexed_up_logic, 8'bxxxx1111);
    check("constant indexed up part to bit", part_indexed_up_bit, 8'b00001111);
    check("dynamic indexed down part to logic", part_indexed_down_logic, 8'b1111xxxx);
    check("dynamic indexed down part to bit", part_indexed_down_bit, 8'b11110000);
    check("constant indexed down part to logic", part_constant_indexed_down_logic, 8'b1111xxxx);
    check("constant indexed down part to bit", part_constant_indexed_down_bit, 8'b11110000);
    check("fully out-of-range part to logic", part_full_oob_logic, 8'bxxxxxxxx);
    check("fully out-of-range part to bit", part_full_oob_bit, 8'b00000000);
    check("four-state part", four_state_part, 8'bxxxx1111);
    base = 6;
    param_part_logic = bit_param[base +: 8];
    param_part_bit = bit_param[base +: 8];
    check("parameter partial part to logic", param_part_logic, 8'bxxxxxx10);
    check("parameter partial part to bit", param_part_bit, 8'b00000010);
    check("ascending in-range part", up[0 +: 4], 8'b00001010);
    check("descending in-range part", down[7 -: 4], 8'b00001010);

    index = 100;
    $display("direct two-state OOB=%b", bits[index]);
    index = 'x;
    $display("direct two-state X=%b", bits[index]);
    $display("direct four-state OOB=%b", logics[100]);

    if (failed == 0) $display("PASSED");
  end
endmodule
