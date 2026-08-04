`begin_keywords "1800-2012"

module main (
  input  logic clk,
  input  logic data,
  output logic state
);
  always_ff @(posedge clk)
    state <= data;
endmodule

`end_keywords
