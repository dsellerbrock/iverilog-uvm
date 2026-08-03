`begin_keywords "1800-2012"

module main(
  input  logic       en,
  input  logic       d,
  output logic [1:0] q
);
  // The out-of-range assignment is a no-op and must not turn the vector-wide
  // latch enable permanently on. q[0] remains a genuine conditional partial
  // write requiring a bit-level latch enable.
  always_latch begin
    q[9 +: 2] = 2'b00;
    if (en)
      q[0] = d;
  end
endmodule

`end_keywords
