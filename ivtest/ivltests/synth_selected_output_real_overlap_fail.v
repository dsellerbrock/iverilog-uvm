`begin_keywords "1800-2012"

module synth_selected_output_real_overlap_fail (
  input  logic clk,
  input  logic reset_n,
  input  logic external_drive,
  input  logic data,
  output logic state
);
  assign state = external_drive;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      state <= 1'b0;
    else
      state <= data;
  end
endmodule

`end_keywords
