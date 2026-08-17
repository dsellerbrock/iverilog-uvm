interface caliptra_bus_if;
  logic [7:0] data;
  logic       valid;
  logic [7:0] held;
endinterface

typedef struct packed {
  logic [7:0] data;
  logic       valid;
} packed_state_t;

module member_driver(
  input logic         clk,
  input logic         latch_enable,
  input logic [7:0]   source,
  caliptra_bus_if     bus,
  output packed_state_t comb_state,
  output packed_state_t ff_state
);
  always_comb begin
    bus.data = source;
    comb_state.data = source ^ 8'hff;
    comb_state.valid = |source;
  end

  always_ff @(posedge clk) begin
    bus.valid <= |source;
    ff_state.data <= source + 1'b1;
    ff_state.valid <= ^source;
  end

  always_latch begin
    if (latch_enable)
      bus.held = source;
  end
endmodule

module sv_synth_integral_member_lvalue;
  logic clk;
  logic latch_enable;
  logic [7:0] source;
  packed_state_t comb_state;
  packed_state_t ff_state;
  caliptra_bus_if bus();

  member_driver dut(
    .clk(clk),
    .latch_enable(latch_enable),
    .source(source),
    .bus(bus),
    .comb_state(comb_state),
    .ff_state(ff_state)
  );

  initial begin
    clk = 0;
    latch_enable = 1;
    source = 8'h3c;
    #1;
    if (bus.data !== 8'h3c || comb_state.data !== 8'hc3 ||
        comb_state.valid !== 1'b1 || bus.held !== 8'h3c)
      $fatal(1, "always_comb/always_latch member assignment failed");

    clk = 1;
    #1;
    if (bus.valid !== 1'b1 || ff_state.data !== 8'h3d ||
        ff_state.valid !== 1'b0)
      $fatal(1, "always_ff member assignment failed");

    clk = 0;
    latch_enable = 0;
    source = 8'ha5;
    #1;
    if (bus.data !== 8'ha5 || comb_state.data !== 8'h5a ||
        bus.held !== 8'h3c)
      $fatal(1, "integral member update or latch hold failed");

    $display("PASSED");
  end
endmodule
