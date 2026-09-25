`timescale 1ns/1ps

// IEEE 1800-2017/2023 16.5.1 and 16.9.3: $past of a whole unpacked
// net-array input must retain the Preponed value when its words change later
// in the antecedent's clock slot.
module aes_uarray_sample_core #(
  parameter bit SecMasking = 0,
  localparam int NumShares = SecMasking ? 2 : 1
) (
  input logic clk, rst_n, alert_i,
  input logic [2:0] state_we, key_len_i,
  input logic [3:0] rnd_ctr,
  input logic [4:0] state_sel,
  input logic [127:0] state_init_i [NumShares],
  input logic [127:0] add_round_key_out_i [NumShares]
);
  localparam logic [4:0] STATE_INIT = 5'b01110,
                         STATE_ROUND = 5'b11000,
                         STATE_CLEAR = 5'b00001;
  logic [127:0] state_d [NumShares], state_q [NumShares];
  logic prd_clearing_equals_output;
  integer whole_failures = 0, scalar_failures = 0;

  always_comb begin
    case (state_sel)
      STATE_INIT:  state_d = state_init_i;
      STATE_ROUND: state_d = add_round_key_out_i;
      STATE_CLEAR: state_d = state_init_i;
      default:     state_d = state_init_i;
    endcase
  end
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_q <= '{default: '0};
    else if (state_we == 3'd3) state_q <= state_d;
  end
  assign prd_clearing_equals_output =
      (state_init_i == add_round_key_out_i);

  whole: assert property (@(posedge clk) disable iff (!rst_n)
      (state_we == 3'd3 && key_len_i == 3'd4 && rnd_ctr == 4'd14) |=>
      (state_q != $past(add_round_key_out_i)) ||
      (state_q == $past(state_init_i)) ||
      $past(prd_clearing_equals_output) || alert_i)
    else whole_failures++;

  scalar: assert property (@(posedge clk) disable iff (!rst_n)
      (state_we == 3'd3 && key_len_i == 3'd4 && rnd_ctr == 4'd14) |=>
      (state_q[0] != $past(add_round_key_out_i[0])) ||
      (state_q[0] == $past(state_init_i[0])) ||
      $past(prd_clearing_equals_output) || alert_i)
    else scalar_failures++;
endmodule

module aes_uarray_sample_probe #(parameter bit Negative = 0) (output bit done);
  localparam logic [4:0] STATE_INIT = 5'b01110,
                         STATE_ROUND = 5'b11000,
                         STATE_CLEAR = 5'b00001;
  bit clk = 0, rst_n = 0, alert_i = 0;
  logic [2:0] state_we = 0, key_len_i = 3'd4;
  logic [3:0] rnd_ctr = 4'd14;
  logic [4:0] state_sel = STATE_CLEAR;
  logic [127:0] state_init [1], round_out [1];
  logic [127:0] source_init, source_round;
  logic [127:0] previous_d, previous_init, previous_out;
  bit pending, nba_pending;
  integer attempts = 0, nba_checks = 0, semantic_passes = 0,
          semantic_failures = 0;

  assign state_init[0] = source_init;
  assign round_out[0] = source_round;
  aes_uarray_sample_core dut (
      .clk(clk), .rst_n(rst_n), .alert_i(alert_i), .state_we(state_we),
      .key_len_i(key_len_i), .rnd_ctr(rnd_ctr), .state_sel(state_sel),
      .state_init_i(state_init), .add_round_key_out_i(round_out));

  initial begin
    while (!done) #5 clk = ~clk;
  end

  // Procedural oracle checks the sampled inputs and resulting NBA state.
  always @(posedge clk) if (rst_n) begin
    if (pending) begin
      if (((dut.state_q[0] != previous_out) ||
           (dut.state_q[0] == previous_init) ||
           (previous_init == previous_out) || alert_i) === 1'b1)
        semantic_passes++;
      else
        semantic_failures++;
      pending = 0;
    end
    if (state_we == 3'd3 && rnd_ctr == 4'd14) begin
      previous_d = dut.state_d[0];
      previous_init = dut.state_init_i[0];
      previous_out = dut.add_round_key_out_i[0];
      attempts++;
      pending = 1;
      nba_pending = 1;
    end
  end
  always @(negedge clk) if (nba_pending) begin
    nba_checks++;
    if (dut.state_q[0] !== previous_d)
      $fatal(1, "NBA state mismatch");
    nba_pending = 0;
  end

  initial begin
    @(negedge clk);
    rst_n = 1;
    source_init = 128'h02000000000000000000000000000000;
    source_round = 128'h8bf1b9fb73b4368acb63450fc4a9c753;
    @(negedge clk);
    state_we = 3'd3;
    @(negedge clk);
    state_sel = Negative ? STATE_ROUND : STATE_INIT;
    source_round = 128'h6363634b6363635f6363637763636377;
    @(posedge clk);
    #0;
    if (!Negative) begin
      // This change is after the second antecedent's Preponed sample.
      source_init = '0;
      source_round = 128'h02000000000000000000000000000000;
    end
    @(negedge clk);
    state_we = 0;
    repeat (2) @(negedge clk);
    #1;
    if (attempts != 2 || nba_checks != 2 ||
        semantic_passes != (Negative ? 1 : 2) ||
        semantic_failures != (Negative ? 1 : 0) ||
        dut.scalar_failures != (Negative ? 1 : 0) ||
        dut.whole_failures != (Negative ? 1 : 0))
      $fatal(1, "whole=%0d scalar=%0d semantic=%0d/%0d NBA=%0d",
             dut.whole_failures, dut.scalar_failures,
             semantic_passes, semantic_failures, nba_checks);
    done = 1;
  end
endmodule

module aes_uarray_second_word_core #(
  parameter bit SecMasking = 1,
  localparam int NumShares = SecMasking ? 2 : 1
) (
  input logic clk, rst_n, enable,
  input logic [7:0] input_words [NumShares]
);
  logic [7:0] state_q [NumShares];
  integer failures = 0;
  always_ff @(posedge clk)
    state_q <= input_words;
  sampled_second_word: assert property (
      @(posedge clk) disable iff (!rst_n)
      enable |=> state_q == $past(input_words))
    else failures++;
endmodule

module aes_uarray_second_word_probe(output bit done);
  bit clk = 0, rst_n = 0, enable = 0;
  logic [7:0] source_0, source_1;
  logic [7:0] input_words [2];
  assign input_words[0] = source_0;
  assign input_words[1] = source_1;
  aes_uarray_second_word_core dut (
      .clk(clk), .rst_n(rst_n), .enable(enable),
      .input_words(input_words));

  initial begin
    while (!done) #5 clk = ~clk;
  end
  initial begin
    @(negedge clk);
    rst_n = 1;
    source_0 = 8'h12;
    source_1 = 8'h34;
    @(negedge clk);
    enable = 1;
    @(posedge clk);
    #0 source_1 = 8'h56;
    @(negedge clk);
    enable = 0;
    if (dut.state_q[0] !== 8'h12 || dut.state_q[1] !== 8'h34)
      $fatal(1, "second-word NBA state mismatch");
    repeat (2) @(negedge clk);
    #1;
    if (dut.failures != 0)
      $fatal(1, "second-word Preponed history failed");
    done = 1;
  end
endmodule

module aes_uarray_held_force_probe(output bit done);
  bit clk = 0, rst_n = 0, enable = 0;
  logic [7:0] source_0, source_1;
  logic [7:0] input_words [2];
  assign input_words[0] = source_0;
  assign input_words[1] = source_1;
  aes_uarray_second_word_core dut (
      .clk(clk), .rst_n(rst_n), .enable(enable),
      .input_words(input_words));

  initial begin
    while (!done) #5 clk = ~clk;
  end
  initial begin
    @(negedge clk);
    rst_n = 1;
    source_0 = 8'h12;
    source_1 = 8'h34;
    #1;
    force dut.input_words[1] = 8'haa;
    enable = 1;
    @(posedge clk);
    #0 source_1 = 8'h56;
    @(negedge clk);
    enable = 0;
    if (dut.state_q[1] !== 8'haa)
      $fatal(1, "forced word NBA state mismatch");
    repeat (2) @(negedge clk);
    #1;
    if (dut.failures != 0)
      $fatal(1, "held-force Preponed history failed");
    release dut.input_words[1];
    done = 1;
  end
endmodule

module aes_uarray_resolved_net_probe(output bit done);
  logic clk = 0;
  logic [7:0] drive0 = 8'h12, drive1 = 8'h34;
  wire [7:0] words [0:1];
  logic [7:0] expected [0:1], prior [0:1];
  bit check_past = 0;
  int current_passes = 0, past_passes = 0, failures = 0, before_check;

  // Opposing explicit-strength drivers make both words resolved vec8 nets.
  assign (pull1, strong0) words[0] = drive0;
  assign (weak1, weak0) words[0] = ~drive0;
  assign (pull1, strong0) words[1] = drive1;
  assign (weak1, weak0) words[1] = ~drive1;

  always @(posedge clk) if (check_past) begin
    drive0 = 8'h9a;
    drive1 = 8'hbc;
  end

  current_sample: assert property (@(posedge clk) words == expected)
    current_passes++;
  else failures++;
  past_sample: assert property (@(posedge clk)
      check_past |-> ($past(words) == prior))
    past_passes++;
  else failures++;

  initial begin
    expected[0] = 8'h12;
    expected[1] = 8'h34;
    prior = expected;
    #5;
    // The clock rises later in this slot; Preponed is still 12/34.
    drive0 = 8'h56;
    drive1 = 8'h78;
    #0 clk = 1;
    #1;
    if (words[0] !== 8'h56 || words[1] !== 8'h78)
      $fatal(1, "first strength-resolved update failed to settle");
    expected[0] = 8'h56;
    expected[1] = 8'h78;
    before_check = past_passes;
    check_past = 1;
    #4 clk = 0;
    #5 clk = 1;
    #1;
    if (words[0] !== 8'h9a || words[1] !== 8'hbc)
      $fatal(1, "post-edge strength-resolved update failed to settle");
    if (failures != 0 || current_passes != 2 ||
        past_passes != before_check + 1)
      $fatal(1, "resolved-array Preponed/$past failed: current=%0d past=%0d failures=%0d",
             current_passes, past_passes, failures);
    done = 1;
  end
endmodule

module sv_assert_net_uarray_preponed;
  wire positive_done, negative_done, second_done, force_done, resolved_done;
  aes_uarray_sample_probe #(.Negative(0)) positive(positive_done);
  aes_uarray_sample_probe #(.Negative(1)) negative(negative_done);
  aes_uarray_second_word_probe second_word(second_done);
  aes_uarray_held_force_probe held_force(force_done);
  aes_uarray_resolved_net_probe resolved_net(resolved_done);
  initial begin
    wait (positive_done && negative_done && second_done && force_done &&
          resolved_done);
    $display("PASSED");
  end
endmodule
