`begin_keywords "1800-2012"

module main(
  input  logic       en,
  input  logic       d,
  output logic [1:0] q
);
  // This is a real conditional partial write, not a disjoint combinational
  // owner. It must retain q[0], so synthesis must keep rejecting it until
  // independent bit-level latch enables are implemented.
  always_latch begin
    if (en)
      q[0] = d;
  end
endmodule

`end_keywords
