`begin_keywords "1800-2012"

module main;
  logic       clk;
  logic       reset_n;
  logic [3:0] data;
  logic       ack_data;
  logic [3:0] state;
  logic       ack;

  // EDN keeps one output unreset in an always_ff process whose other outputs
  // use asynchronous reset. The omitted output must hold across the reset
  // edge and across clocks while reset remains asserted.
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      state <= '0;
    end else begin
      state <= data;
      ack <= ack_data;
    end
  end

  task automatic tick;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
  endtask

  task automatic fail(input string label,
                      input logic [3:0] expected_state,
                      input logic expected_ack);
    $display("FAILED -- %s state=%h ack=%b expected=%h/%b",
             label, state, ack, expected_state, expected_ack);
    $finish;
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    reset_n = 1'b1;
    data = 4'ha;
    ack_data = 1'b1;
    tick();
    if (state !== 4'ha || ack !== 1'b1)
      fail("initial update", 4'ha, 1'b1);

    reset_n = 1'b0;
    #1;
    if (state !== 4'h0 || ack !== 1'b1)
      fail("reset edge", 4'h0, 1'b1);

    data = 4'h5;
    ack_data = 1'b0;
    tick();
    if (state !== 4'h0 || ack !== 1'b1)
      fail("clock while reset", 4'h0, 1'b1);

    reset_n = 1'b1;
    tick();
    if (state !== 4'h5 || ack !== 1'b0)
      fail("update after reset", 4'h5, 1'b0);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
