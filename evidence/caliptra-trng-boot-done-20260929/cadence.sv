module tb;
  logic clk = 0;
  logic enable = 0;
  logic [3:0] slow_data, fast_data;
  logic slow_valid, fast_valid;
  logic [3:0] slow_samples [0:95], fast_samples [0:95];
  integer cycle = 0;
  integer slow_count = 0, fast_count = 0;
  integer slow_first = -1, slow_last = -1;
  integer fast_first = -1, fast_last = -1;

  always #5 clk = ~clk;
  physical_rng slow (.clk(clk), .enable(enable), .data(slow_data), .valid(slow_valid));
  physical_rng #(.DutyCycle(50)) fast
    (.clk(clk), .enable(enable), .data(fast_data), .valid(fast_valid));

  initial begin
    repeat (3) @(negedge clk);
    enable = 1;
  end

  always @(posedge clk) begin
    cycle = cycle + 1;
    if (slow_valid && slow_count < 96) begin
      if (slow_count == 0) slow_first = cycle;
      if (slow_count == 95) slow_last = cycle;
      slow_samples[slow_count] = slow_data;
      slow_count = slow_count + 1;
    end
    if (fast_valid && fast_count < 96) begin
      if (fast_count == 0) fast_first = cycle;
      if (fast_count == 95) fast_last = cycle;
      fast_samples[fast_count] = fast_data;
      fast_count = fast_count + 1;
    end
    if (slow_count == 96 && fast_count == 96) begin
      for (integer i = 0; i < 96; i = i + 1)
        if (slow_samples[i] !== fast_samples[i]) $fatal(1, "seed mismatch at %0d", i);
      if (slow_last - slow_first != 95*500) $fatal(1, "slow cadence mismatch");
      if (fast_last - fast_first != 95*50) $fatal(1, "fast cadence mismatch");
      $display("PASS first96_equal slow_span=%0d fast_span=%0d", slow_last - slow_first, fast_last - fast_first);
      $finish;
    end
    if (cycle > 50000) $fatal(1, "timeout");
  end
endmodule
