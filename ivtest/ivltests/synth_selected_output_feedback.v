`begin_keywords "1800-2012"

module selected_output_leaf #(parameter int WIDTH = 8) (
  input  logic             clk,
  input  logic             reset_n,
  input  logic [WIDTH-1:0] data,
  output logic [WIDTH-1:0] state
);
  always_ff @(posedge clk or negedge reset_n) begin
    if (reset_n == 0)
      state <= '0;
    else
      state <= data;
  end
endmodule

module selected_output_middle #(parameter int WIDTH = 8) (
  input  logic             clk,
  input  logic             reset_n,
  input  logic [WIDTH-1:0] data,
  output logic [WIDTH-1:0] state
);
  selected_output_leaf #(WIDTH) u_leaf(.*);
endmodule

module selected_output_feedback #(parameter int WIDTH = 8) (
  input  logic             clk,
  input  logic             reset_n,
  input  logic             enable,
  input  logic [WIDTH-1:0] data,
  output logic [WIDTH-1:0] state
);
  logic update;
  logic [WIDTH-1:0] next_state;

  // Reading an output internally does not make the selected output actual an
  // inout. It remains driven outward by the nested flop instance.
  assign update = (|(data ^ state)) & enable;
  assign next_state = update ? data : state;
  selected_output_middle #(WIDTH) u_middle(
    .clk, .reset_n, .data(next_state), .state
  );
endmodule

module selected_output_bank (
  input  logic        clk,
  input  logic        reset_n,
  input  logic        enable_flag,
  input  logic        enable_hi,
  input  logic        enable_lo,
  input  logic [16:0] data,
  output logic [16:0] state
);
  selected_output_feedback #(1) u_flag(
    .clk, .reset_n, .enable(enable_flag),
    .data(data[16]), .state(state[16])
  );
  selected_output_feedback #(8) u_hi(
    .clk, .reset_n, .enable(enable_hi),
    .data(data[15:8]), .state(state[15:8])
  );
  selected_output_feedback #(8) u_lo(
    .clk, .reset_n, .enable(enable_lo),
    .data(data[7:0]), .state(state[7:0])
  );
endmodule

module synth_selected_output_feedback;
  logic clk = 1'b0;
  logic reset_n = 1'b1;
  logic enable_flag = 1'b0;
  logic enable_hi = 1'b0;
  logic enable_lo = 1'b0;
  logic [16:0] data = 17'h00000;
  logic [16:0] state;

  selected_output_bank dut(.*);

  (* ivl_synthesis_off *)
  initial begin
    #1 reset_n = 1'b0;
    #1;
    if (state !== 17'h00000)
      $fatal(1, "selected output reset failed: %h", state);

    reset_n = 1'b1;
    enable_hi = 1'b1;
    data = 17'h0a55a;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
    if (state !== 17'h0a500)
      $fatal(1, "high selected output update failed: %h", state);

    enable_hi = 1'b0;
    enable_lo = 1'b1;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
    if (state !== 17'h0a55a)
      $fatal(1, "low selected output update failed: %h", state);

    enable_lo = 1'b0;
    enable_flag = 1'b1;
    data[16] = 1'b1;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
    if (state !== 17'h1a55a)
      $fatal(1, "bit-selected output update failed: %h", state);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
