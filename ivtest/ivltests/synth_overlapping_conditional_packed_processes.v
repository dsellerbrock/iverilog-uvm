`begin_keywords "1800-2012"

module main(
  input  logic       clk,
  input  logic       en,
  input  logic [1:0] d,
  output logic [1:0] q
);
  // Ownership is the union of bits written on every branch, not merely the
  // bits written unconditionally. The conditional writer must therefore
  // conflict with the second process on q[0].
  always_ff @(posedge clk) begin
    if (en)
      q[0] <= d[0];
  end

  always_ff @(posedge clk)
    q[0] <= d[1];
endmodule

`end_keywords
