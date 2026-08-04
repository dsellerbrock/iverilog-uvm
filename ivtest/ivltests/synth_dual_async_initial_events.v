`begin_keywords "1800-2012"

module dual_initial_event_dut (
  input  logic clk,
  input  logic reset_n,
  input  logic aset,
  input  logic data,
  output logic state
);
  always_ff @(posedge clk, negedge reset_n, posedge aset) begin
    if (!reset_n)
      state <= 1'b0;
    else if (aset)
      state <= 1'b1;
    else
      state <= data;
  end
endmodule

module main;
  // Static variable initialization precedes activation of always processes.
  // These levels therefore establish baselines; they are not source events.
  logic decl_clk = 1'b0;
  logic decl_inactive_reset_n = 1'b1;
  logic decl_active_reset_n = 1'b0;
  logic decl_inactive_aset = 1'b0;
  logic decl_active_aset = 1'b1;
  logic decl_data = 1'b1;

  // Blocking assignments in an initial process execute after always
  // processes are active, so their X-to-0/1 transitions are real events.
  logic block_clear_clk, block_clear_reset_n, block_clear_aset;
  logic block_set_clk, block_set_reset_n, block_set_aset;
  logic block_clock_clk, block_clock_reset_n, block_clock_aset;
  logic later_clk = 1'b0;
  logic later_reset_n = 1'b1;
  logic later_aset = 1'b0;

  logic q_decl_inactive;
  logic q_decl_clear;
  logic q_decl_set;
  logic q_decl_both;
  logic q_literal_clear;
  logic q_literal_set;
  logic q_literal_clock;
  logic q_block_clear;
  logic q_block_set;
  logic q_block_clock;
  logic q_later_clear;

  dual_initial_event_dut u_decl_inactive(
    decl_clk, decl_inactive_reset_n, decl_inactive_aset, decl_data,
    q_decl_inactive
  );
  dual_initial_event_dut u_decl_clear(
    decl_clk, decl_active_reset_n, decl_inactive_aset, decl_data, q_decl_clear
  );
  dual_initial_event_dut u_decl_set(
    decl_clk, decl_inactive_reset_n, decl_active_aset, decl_data, q_decl_set
  );
  dual_initial_event_dut u_decl_both(
    decl_clk, decl_active_reset_n, decl_active_aset, decl_data, q_decl_both
  );
  dual_initial_event_dut u_literal_clear(
    1'b0, 1'b0, 1'b0, 1'b1, q_literal_clear
  );
  dual_initial_event_dut u_literal_set(
    1'b0, 1'b1, 1'b1, 1'b0, q_literal_set
  );
  dual_initial_event_dut u_literal_clock(
    1'b1, 1'b1, 1'b0, 1'b1, q_literal_clock
  );
  dual_initial_event_dut u_block_clear(
    block_clear_clk, block_clear_reset_n, block_clear_aset, 1'b1,
    q_block_clear
  );
  dual_initial_event_dut u_block_set(
    block_set_clk, block_set_reset_n, block_set_aset, 1'b0, q_block_set
  );
  dual_initial_event_dut u_block_clock(
    block_clock_clk, block_clock_reset_n, block_clock_aset, 1'b1,
    q_block_clock
  );
  dual_initial_event_dut u_later_clear(
    later_clk, later_reset_n, later_aset, 1'b1, q_later_clear
  );

  (* ivl_synthesis_off *)
  initial begin
    block_clear_clk = 1'b0;
    block_clear_reset_n = 1'b0;
    block_clear_aset = 1'b0;
    block_set_clk = 1'b0;
    block_set_reset_n = 1'b1;
    block_set_aset = 1'b1;
    block_clock_clk = 1'b1;
    block_clock_reset_n = 1'b1;
    block_clock_aset = 1'b0;

    #1;
    if ({q_decl_inactive, q_decl_clear, q_decl_set, q_decl_both} !== 4'bxxxx ||
        {q_literal_clear, q_literal_set, q_literal_clock} !== 3'bxxx ||
        {q_block_clear, q_block_set, q_block_clock} !== 3'b011) begin
      $display("FAILED -- initial dual controls static=%b%b%b%b literals=%b%b%b time0=%b%b%b",
               q_decl_inactive, q_decl_clear, q_decl_set, q_decl_both,
               q_literal_clear, q_literal_set, q_literal_clock,
               q_block_clear, q_block_set, q_block_clock);
      $finish;
    end

    later_reset_n = 1'b0;
    #1;
    if (q_later_clear !== 1'b0) begin
      $display("FAILED -- later clear event state=%b", q_later_clear);
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
