`timescale 1ns/1ps

module aes_clear_core #(
  parameter bit SecMasking = 0,
  localparam int NumShares = SecMasking ? 2 : 1
) (
  input logic clk, rst_n, alert_i,
  input logic [2:0] state_we, key_len_i,
  input logic [3:0] rnd_ctr,
  input logic [1:0] state_sel,
  input logic [3:0][3:0][7:0] state_init_i [NumShares],
  input logic [3:0][3:0][7:0] prd_clearing_state_i [NumShares],
  input logic [3:0][3:0][7:0] add_round_key_out_i [NumShares]
);
  localparam logic [1:0] STATE_INIT = 0, STATE_ROUND = 1, STATE_CLEAR = 2;
  logic [3:0][3:0][7:0] state_d [NumShares], state_q [NumShares];
  logic prd_clearing_equals_output;
  integer sva_failures = 0;

  always_comb begin
    case (state_sel)
      STATE_INIT:  state_d = state_init_i;
      STATE_ROUND: state_d = add_round_key_out_i;
      STATE_CLEAR: state_d = prd_clearing_state_i;
      default:     state_d = prd_clearing_state_i;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_q <= '{default: '0};
    else if (state_we == 3'd3) state_q <= state_d;
  end

  assign prd_clearing_equals_output =
      (prd_clearing_state_i == add_round_key_out_i);

  AesSecCmDataRegKeySca: assert property (
    @(posedge clk) disable iff (!rst_n)
    ((state_we == 3'd3) &&
      ((key_len_i == 3'd1 && rnd_ctr == 4'd10) ||
       (key_len_i == 3'd2 && rnd_ctr == 4'd12) ||
       (key_len_i == 3'd4 && rnd_ctr == 4'd14))) |=>
      (state_q != $past(add_round_key_out_i)) ||
      (state_q == $past(state_init_i)) ||
      $past(prd_clearing_equals_output) || alert_i
  ) else begin
    sva_failures++;
    $display("SVA_FAIL case_time=%0t", $time);
  end
endmodule


module tb;
  parameter bit SecMasking = 0;
  localparam int NumShares = SecMasking ? 2 : 1;
  localparam logic [1:0] STATE_INIT = 0, STATE_ROUND = 1, STATE_CLEAR = 2;
  logic clk = 0, rst_n = 0, alert_i = 0;
  logic [2:0] state_we = 0, key_len_i = 3'd4;
  logic [3:0] rnd_ctr = 4'd14;
  logic [1:0] state_sel = STATE_CLEAR;
  logic [3:0][3:0][7:0] state_init [NumShares], round_out [NumShares];
  logic [127:0] pre_state_d, prev_init, prev_prd, prev_out;
  logic nba_pending = 0, semantic_pending = 0;
  integer attempts = 0, nba_checks = 0, nba_failures = 0;
  integer semantic_passes = 0, semantic_failures = 0;
  bit negative_mode;

  always #5 clk = ~clk;
  aes_clear_core #(.SecMasking(SecMasking)) dut (
    .clk(clk), .rst_n(rst_n), .state_we(state_we), .key_len_i(key_len_i), .rnd_ctr(rnd_ctr),
    .alert_i(alert_i), .state_sel(state_sel), .state_init_i(state_init),
    .prd_clearing_state_i(state_init), .add_round_key_out_i(round_out)
  );

  // Every attempt is checked against a procedural, four-state semantic oracle
  // at the following rising edge. This check is independent of SVA history.
  always @(posedge clk) begin
    if (rst_n) begin
      if (semantic_pending) begin
        if (((dut.state_q[0] != prev_out) ||
             (dut.state_q[0] == prev_init) ||
             (prev_prd == prev_out) || alert_i) === 1'b1) begin
          semantic_passes++;
          $display("SEMANTIC_PASS attempt=%0d q=%h init=%h out=%h", attempts,
                   dut.state_q[0], prev_init, prev_out);
        end else begin
          semantic_failures++;
          $display("SEMANTIC_FAIL attempt=%0d q=%h init=%h out=%h", attempts,
                   dut.state_q[0], prev_init, prev_out);
        end
        semantic_pending = 0;
      end
      if (state_we == 3'd3 && key_len_i == 3'd4 && rnd_ctr == 4'd14) begin
        pre_state_d = dut.state_d[0];
        prev_init = dut.state_init_i[0];
        prev_prd = dut.prd_clearing_state_i[0];
        prev_out = dut.add_round_key_out_i[0];
        nba_pending = 1;
        semantic_pending = 1;
        attempts++;
        $display("ATTEMPT %0d sel=%h d=%h init=%h out=%h",
                 attempts, state_sel, pre_state_d, prev_init, prev_out);
      end
    end
  end
  always @(negedge clk) begin
    if (nba_pending) begin
      nba_checks++;
      if (dut.state_q[0] !== pre_state_d) begin
        nba_failures++;
        $display("NBA_ORACLE_FAIL attempt=%0d actual=%h expected=%h",
                 attempts, dut.state_q[0], pre_state_d);
      end
      nba_pending = 0;
    end
  end

  initial begin
    negative_mode = $test$plusargs("NEGATIVE");
    @(negedge clk);
    rst_n = 1;
    state_init[0] = 128'hB1B2B3B4_B5B6B7B8_B9BABBBC_BDBEBFC0;
    round_out[0] = 128'hA1A2A3A4_A5A6A7A8_A9AAABAC_ADAEAFA0;
    state_sel = STATE_CLEAR;
    @(negedge clk);
    state_we = 3'd3;
    @(negedge clk);
    state_sel = negative_mode ? STATE_ROUND : STATE_INIT;
    round_out[0] = 128'hC1C2C3C4_C5C6C7C8_C9CACBCC_CDCECFD0;
    @(negedge clk);
    state_we = 3'd0;
    repeat (2) @(negedge clk);
    #1;
    $display("RESULT negative=%0d attempts=%0d nba_checks=%0d nba_failures=%0d semantic_passes=%0d semantic_failures=%0d sva_failures=%0d",
             negative_mode, attempts, nba_checks, nba_failures,
             semantic_passes, semantic_failures, dut.sva_failures);
    if (attempts != 2 || nba_checks != 2 || nba_failures != 0 ||
        semantic_passes != (negative_mode ? 1 : 2) ||
        semantic_failures != (negative_mode ? 1 : 0) ||
        dut.sva_failures != (negative_mode ? 1 : 0))
      $fatal(1, "overlap result mismatch");
    $display("EXPECTED_RESULT_PASS negative=%0d", negative_mode);
    $finish;
  end
endmodule
