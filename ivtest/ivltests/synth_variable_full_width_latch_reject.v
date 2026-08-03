`begin_keywords "1800-2012"

module main(
  input  logic [2:0] index,
  input  logic [3:0] d,
  output logic [3:0] q
);
  // Equal widths do not make this a whole-vector assignment. The run-time
  // base can be partially or wholly out of range, so independent bit-level
  // latch enables are still required.
  always_latch q[index +: 4] = d;
endmodule

`end_keywords
