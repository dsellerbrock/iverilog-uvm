`timescale 1ns/1ps

module top;
  logic [1:0] src;
  wire [1:0] #(7, 3, 5) delayed;
  assign delayed = src;

  logic pulse;
  wire #(10, 12, 14) inertial;
  assign inertial = pulse;

  // Keep one long event pending while another bit repeatedly selects a
  // short delay. Re-arming after each short callback must not enqueue a new
  // duplicate callback for the same long due time.
  logic [1:0] churn_src;
  wire [1:0] #(1000000, 1, 1) churn;
  assign churn = churn_src;

  task automatic expect_vec(input logic [1:0] expected, input string where);
    if (delayed !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b", where, $time,
               delayed, expected);
      $fatal(1);
    end
  endtask

  task automatic expect_bit(input logic expected, input string where);
    if (inertial !== expected) begin
      $display("FAILED %s t=%0t got=%b expected=%b", where, $time,
               inertial, expected);
      $fatal(1);
    end
  endtask

  initial begin
    src = 2'b01;
    pulse = 1'b0;
    churn_src = 2'b00;
    #3 expect_vec(2'b0x, "initial per-bit fall");
    #4 expect_vec(2'b01, "initial per-bit rise");
    #5 expect_bit(1'b0, "initial scalar fall");

    src = 2'b10;
    #3.001 expect_vec(2'b00, "mixed transition fall first");
    #4 expect_vec(2'b10, "mixed transition rise second");

    src = 2'bx0;
    #3.001 expect_vec(2'bx0, "transition to X uses minimum delay");

    // Cancel the earliest event and replace it with a later one. The stale
    // callback must re-arm the replacement instead of stranding it.
    pulse = 1'b1;
    #1 pulse = 1'bx;
    #9.001 expect_bit(1'b0, "old wake does not fire replacement early");
    #1 expect_bit(1'bx, "later replacement fires");

    // Cancel to an empty bucket set, then enqueue before the stale callback.
    pulse = 1'b0;
    #12.001 expect_bit(1'b0, "return to zero");
    pulse = 1'b1;
    #1 pulse = 1'b0;
    #1 pulse = 1'b1;
    #8.001 expect_bit(1'b0, "empty-cancel obsolete wake");
    #2 expect_bit(1'b1, "empty-cancel replacement fires");

    #1.001;
    if (churn !== 2'b00) begin
      $display("FAILED churn initial t=%0t got=%b", $time, churn);
      $fatal(1);
    end
    churn_src[0] = 1'b1;
    repeat (4096) begin
      churn_src[1] = 1'bx;
      #1.001;
      churn_src[1] = 1'b0;
      #1.001;
    end
    churn_src[0] = 1'b0;
    if (churn !== 2'b00) begin
      $display("FAILED churn duplicate wake t=%0t got=%b", $time, churn);
      $fatal(1);
    end

    $display("PASSED");
  end
endmodule
