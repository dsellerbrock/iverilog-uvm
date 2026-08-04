`begin_keywords "1800-2012"

module main (
  input  logic clk,
  input  logic clear,
  input  logic data,
  output logic state
);
  always_ff @(posedge clk, posedge clear) begin
    if (clear)
      state <= 1'b0;
    else
      state <= data;
  end
endmodule

`end_keywords
