`begin_keywords "1800-2012"

module main;
  logic       clk;
  logic       reset_n;
  logic [7:0] data;
  logic [7:0] state;

  // The reset covers only half of the bits this same process owns. This is a
  // genuine partial asynchronous load and remains outside the supported
  // flip-flop model; it must not be confused with disjoint field ownership.
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n)
      state[3:0] <= '0;
    else
      state <= data;
  end
endmodule

`end_keywords
