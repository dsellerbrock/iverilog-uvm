`begin_keywords "1800-2012"

module main (
  input  logic clk,
  input  logic reset_n,
  input  logic aset,
  output logic state
);
  always_ff @(posedge clk, negedge reset_n, posedge aset) begin
    if (!reset_n)
      state <= 1'b0;
    if (aset)
      state <= 1'b1;
  end
endmodule

`end_keywords
