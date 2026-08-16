`begin_keywords "1800-2012"

module synth_async_reset_equality;
  logic clk = 1'b0;
  logic reset_n = 1'b1;
  logic reset_h = 1'b0;
  logic data = 1'b0;
  logic q_eq_zero;
  logic q_zero_eq;
  logic q_ne_one;
  logic q_eq_one;
  logic q_zero_ne;

  // Caliptra uses the first form. The remaining predicates prove the same
  // one-bit polarity in both operand orders and for both event edges.
  always_ff @(posedge clk or negedge reset_n) begin
    if (reset_n == 0)
      q_eq_zero <= 1'b0;
    else
      q_eq_zero <= data;
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (0 == reset_n)
      q_zero_eq <= 1'b0;
    else
      q_zero_eq <= data;
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (reset_n != 1)
      q_ne_one <= 1'b0;
    else
      q_ne_one <= data;
  end

  always_ff @(posedge clk or posedge reset_h) begin
    if (reset_h == 1)
      q_eq_one <= 1'b0;
    else
      q_eq_one <= data;
  end

  always_ff @(posedge clk or posedge reset_h) begin
    if (0 != reset_h)
      q_zero_ne <= 1'b0;
    else
      q_zero_ne <= data;
  end

  (* ivl_synthesis_off *)
  initial begin
    #1;
    reset_n = 1'b0;
    reset_h = 1'b1;
    #1;
    if ({q_eq_zero, q_zero_eq, q_ne_one, q_eq_one, q_zero_ne} !== 5'b0)
      $fatal(1, "asynchronous comparison reset failed: %b%b%b%b%b",
             q_eq_zero, q_zero_eq, q_ne_one, q_eq_one, q_zero_ne);

    reset_n = 1'b1;
    reset_h = 1'b0;
    data = 1'b1;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
    if ({q_eq_zero, q_zero_eq, q_ne_one, q_eq_one, q_zero_ne} !== 5'b11111)
      $fatal(1, "clocked data update failed: %b%b%b%b%b",
             q_eq_zero, q_zero_eq, q_ne_one, q_eq_one, q_zero_ne);

    reset_n = 1'b0;
    reset_h = 1'b1;
    #1;
    if ({q_eq_zero, q_zero_eq, q_ne_one, q_eq_one, q_zero_ne} !== 5'b0)
      $fatal(1, "second asynchronous comparison reset failed: %b%b%b%b%b",
             q_eq_zero, q_zero_eq, q_ne_one, q_eq_one, q_zero_ne);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
