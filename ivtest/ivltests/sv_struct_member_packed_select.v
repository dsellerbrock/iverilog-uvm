typedef struct {
  logic [7:0] flags[2];
} payload_t;

typedef struct {
  payload_t body;
} outer_t;

module sv_struct_member_packed_select;
  payload_t direct;
  outer_t data;
  integer index;
  logic direct_bit;
  logic bit_value;
  logic [2:0] part_value;
  logic oob_bit;
  logic [2:0] oob_part;

  initial begin
    index = 1;
    direct.flags[1] = 8'ha5;
    data.body.flags[0] = 8'h3c;
    data.body.flags[1] = 8'ha5;

    direct_bit = direct.flags[index][0];
    bit_value = data.body.flags[index][0];
    part_value = data.body.flags[index][6:4];
    oob_bit = data.body.flags[index][8];
    oob_part = data.body.flags[index][9:7];
    if (direct_bit !== 1'b1 || bit_value !== 1'b1
        || part_value !== 3'b010)
      $fatal(1, "packed read got direct=%b bit=%b part=%b",
             direct_bit, bit_value, part_value);
    if (oob_bit !== 1'bx || oob_part !== 3'bxx1)
      $fatal(1, "out-of-range read got bit=%b part=%b", oob_bit, oob_part);

    data.body.flags[index][7:5] = 3'b011;
    if (data.body.flags[1] !== 8'h65)
      $fatal(1, "packed part write changed wrong element: %h",
             data.body.flags[1]);
    data.body.flags[index][9:7] = 3'b101;
    if (data.body.flags[1] !== 8'he5 || data.body.flags[0] !== 8'h3c)
      $fatal(1, "partial out-of-range write got [%h,%h]",
             data.body.flags[0], data.body.flags[1]);

    $display("PASS: packed selects after unpacked struct member indexing");
  end
endmodule
