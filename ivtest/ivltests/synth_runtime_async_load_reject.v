`begin_keywords "1800-2012"

module main(
  input  logic       clk,
  input  logic       reset_n,
  input  logic       index,
  input  logic [3:0] data,
  output logic [3:0] state
);
  typedef struct packed {
    integer selected_index;
  } target_cfg_t;

  localparam target_cfg_t TargetCfg = '{selected_index: 2};

  // The loop index shadows a run-time module signal with the same basename.
  // The qualified `main.index' reference must be distinguished by signal
  // identity rather than mistaken for the unrolled index value. The complete
  // condition is not contextually constant, so it remains an asynchronous
  // data load that synthesis must reject.
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      for (int index = 0; index < 4; index++) begin
        if ((index == TargetCfg.selected_index) && main.index)
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
