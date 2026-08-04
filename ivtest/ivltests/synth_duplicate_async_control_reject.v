`begin_keywords "1800-2012"

module main (
  input  logic clk,
  input  logic reset_a_n,
  input  logic reset_b_n,
  input  logic data,
  output logic state
);
  always_ff @(posedge clk, negedge reset_a_n, negedge reset_b_n) begin
    if (!reset_a_n)
      state <= 1'b0;
    else if (!reset_b_n)
      state <= 1'b0;
    else
      state <= data;
  end
endmodule

`end_keywords
