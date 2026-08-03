`begin_keywords "1800-2012"

module main(
  input  logic       en,
  input  logic [1:0] d,
  output logic [1:0] q
);
  // The unconditional q[1] write makes the vector-wide process enable high,
  // but q[0] must still retain its value while en is low. This requires an
  // independent bit-level latch enable and must remain a loud rejection.
  always_latch begin
    if (en)
      q[0] = d[0];
    q[1] = d[1];
  end
endmodule

`end_keywords
