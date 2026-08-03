`begin_keywords "1800-2012"

module main(
  input  logic       clk,
  input  logic       reset_n,
  input  logic [3:0] data,
  output logic [3:0] state
);
  localparam logic Unknown = 1'bx;

  // This condition contains only an unrolled loop index and a parameter, but
  // its value is X in the selected iteration. Synthesis must retain the
  // established unknown-condition path instead of choosing either reset
  // branch as a defined constant. The resulting asynchronous load remains
  // unsupported.
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      for (int index = 0; index < 4; index++) begin
        if ((index == 2) && Unknown)
          state[index] <= 1'b1;
        else
          state[index] <= 1'b0;
      end
    end else begin
      state <= data;
    end
  end
endmodule

`end_keywords
