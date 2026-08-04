`begin_keywords "1800-2012"

module main (
  input  logic clk,
  input  logic reset_n,
  input  logic aset,
  input  logic data,
  output logic reset_state,
  output logic omitted_state
);
  always_ff @(posedge clk, negedge reset_n, posedge aset) begin
    if (!reset_n)
      reset_state <= 1'b0;
    else if (aset) begin
      reset_state <= 1'b1;
      omitted_state <= 1'b1;
    end else begin
      reset_state <= data;
      omitted_state <= data;
    end
  end
endmodule

`end_keywords
