// An unpacked-array concatenation operand must be assignment-compatible
// with the destination element type (IEEE 1800-2017 10.10).
module main;
  int qi[$];
  string qs[$];

  initial
    qi = {qi, qs};
endmodule
