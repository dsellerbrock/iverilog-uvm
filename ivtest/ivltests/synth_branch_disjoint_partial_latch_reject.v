`begin_keywords "1800-2012"

module main(
  input  logic       en,
  input  logic [1:0] d,
  output logic [1:0] q
);
  // The vector-wide process enable is high because each branch writes some
  // bit, but each individual bit is incomplete and must retain state on the
  // opposite branch. This still requires independent bit-level enables.
  always_latch begin
    if (en)
      q[0] = d[0];
    else
      q[1] = d[1];
  end
endmodule

`end_keywords
