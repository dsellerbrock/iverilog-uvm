`begin_keywords "1800-2012"

module main (
  input  logic clk,
  input  logic set_a,
  input  logic set_b,
  input  logic data,
  output logic state
);
  always_ff @(posedge clk, posedge set_a, posedge set_b) begin
    if (set_a)
      state <= 1'b1;
    else if (set_b)
      state <= 1'b1;
    else
      state <= data;
  end
endmodule

`end_keywords
