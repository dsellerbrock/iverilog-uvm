`begin_keywords "1800-2012"

module main(
  input  logic       clk,
  input  logic       rst_n,
  input  logic [1:0] d,
  output logic [1:0] q
);
  // Partial asynchronous reset is deliberately unsupported in synthesis.
  // The primary pass must diagnose it and the legacy fallback must reject it
  // without asserting or crashing the compiler.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      q[0] <= 1'b0;
    else
      q <= d;
  end
endmodule

`end_keywords
