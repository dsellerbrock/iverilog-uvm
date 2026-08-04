`begin_keywords "1800-2012"

module main (
  input  logic clk,
  input  logic clear,
  input  logic set,
  input  logic data,
  output logic state
);
  always_ff @(posedge clk, posedge clear, posedge set) begin
    if (clear)
      state <= 1'b0;
    else if (set)
      state <= 1'b1;
    else
      state <= data;
  end
endmodule

`end_keywords
