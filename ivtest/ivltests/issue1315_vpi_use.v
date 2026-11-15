// Issue #1315 (IEEE 1800-2023 37.58 details 1 and 2): vpiUse returns the
// uses of a vector and, for a bit, also the uses of the whole vector and
// of any part-select containing the bit. $probe checks them.
module child(input wire [1:0] p);
endmodule

module top;
  logic [7:0] data;
  wire [7:0] whole;
  wire bit_use;
  wire [2:0] part_use;
  assign whole = data;
  assign bit_use = data[2];
  assign part_use = data[4:2];
  child c(data[6:5]);
  initial #1 $probe;
endmodule
