`begin_keywords "1800-2012"

module main(
  input  logic       d,
  input  logic [1:0] index,
  output logic [3:0] q
);
  // A run-time bit select potentially writes every bit but does not write any
  // particular bit on every activation. Without a whole-vector default this
  // is a bank of independently enabled latches, which is not yet supported.
  always_latch q[index] = d;
endmodule

`end_keywords
