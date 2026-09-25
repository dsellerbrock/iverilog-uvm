`timescale 1ns/1ps
module aes_vec8_preponed;
  logic clk = 0;
  logic [7:0] drive0 = 8'h12, drive1 = 8'h34;
  wire [7:0] words [0:1];
  logic [7:0] expected [0:1], prior [0:1];
  bit check_past = 0;
  int current_passes = 0, past_passes = 0, failures = 0, before_check;

  assign (pull1, strong0) words[0] = drive0;
  assign (weak1, weak0) words[0] = ~drive0;
  assign (pull1, strong0) words[1] = drive1;
  assign (weak1, weak0) words[1] = ~drive1;

  // Change both resolved words after the second edge, in its Active region.
  always @(posedge clk) if (check_past) begin
    drive0 = 8'h9a;
    drive1 = 8'hbc;
  end

  current_sample: assert property (@(posedge clk) words == expected)
    current_passes++;
  else
    failures++;
  past_sample: assert property (@(posedge clk)
      check_past |-> ($past(words) == prior))
    past_passes++;
  else
    failures++;

  initial begin
    expected[0] = 8'h12;
    expected[1] = 8'h34;
    prior = expected;
    #5;
    // The clock rises later in this same time slot; Preponed is still 12/34.
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
      $fatal(1, "whole-array Preponed/$past failed: current=%0d past=%0d failures=%0d",
             current_passes, past_passes, failures);
    $display("PASS strength-resolved whole-array Preponed/$past");
    $finish;
  end
endmodule
