module top;
  parameter bit [7:0] CMD_LIST[] = {8'h03, 8'h0b};
  parameter bit [7:0] SINGLETON[] = {8'h5a};
  parameter bit [2:0] GRID[0:1][0:1] =
      '{'{3'd1, 3'd2}, '{3'd5, 3'd7}};
  parameter logic [3:0] WILDCARDS[] = {4'b10x1, 4'bzz00};
  parameter logic signed [3:0] SIGNED_WILDCARDS[] = {4'bx001};
  bit [7:0] opcode;
  bit [2:0] small_value;
  bit [3:0] nibble;
  bit signed [7:0] signed_value;

  class empty_inside_set;
    rand bit [7:0] value;
    bit [7:0] values[$];
    constraint c { value inside {values}; }
  endclass
  empty_inside_set empty_item;

  initial begin
    if (!std::randomize(opcode) with {
          opcode inside {CMD_LIST}; opcode == 8'h03;
        } || opcode != 8'h03) $fatal(1, "first array element");
    if (!std::randomize(opcode) with {
          opcode inside {CMD_LIST}; opcode == 8'h0b;
        } || opcode != 8'h0b) $fatal(1, "last array element");

    opcode = 8'h55;
    if (std::randomize(opcode) with {
          opcode inside {CMD_LIST}; opcode == 8'hff;
        }) $fatal(1, "nonmember unexpectedly matched");
    if (opcode != 8'h55) $fatal(1, "failed solve did not roll back");

    if (!std::randomize(opcode) with {
          opcode inside {SINGLETON}; opcode == 8'h5a;
        } || opcode != 8'h5a) $fatal(1, "singleton array");
    if (!std::randomize(small_value) with {
          small_value inside {GRID}; small_value == 3'd7;
        } || small_value != 3'd7) $fatal(1, "multidimensional array");

    if (!std::randomize(nibble) with {
          nibble inside {WILDCARDS}; nibble == 4'b1011;
        } || nibble != 4'b1011) $fatal(1, "X wildcard bit");
    if (!std::randomize(nibble) with {
          nibble inside {WILDCARDS}; nibble == 4'b0100;
        } || nibble != 4'b0100) $fatal(1, "Z wildcard bits");
    if (std::randomize(nibble) with {
          nibble inside {WILDCARDS}; nibble == 4'b0111;
        }) $fatal(1, "wildcard control matched nonmember");

    if (!std::randomize(signed_value) with {
          signed_value inside {SIGNED_WILDCARDS};
          signed_value == 8'shA1;
        } || signed_value != 8'shA1)
      $fatal(1, "signed wildcard extension");

    empty_item = new;
    empty_item.value = 8'h33;
    if (empty_item.randomize())
      $fatal(1, "empty array unexpectedly matched");
    if (empty_item.value != 8'h33)
      $fatal(1, "empty-array failure did not roll back");
    $display("PASSED");
  end
endmodule
