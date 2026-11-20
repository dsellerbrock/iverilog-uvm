`timescale 1ns/1ns

module main;
  reg ref_clk = 0, data_clk = 0, enabled = 1;
  reg time_notifier = 0, full_notifier = 0;
  reg idle_ref = 0;
  int time_count = 0, full_count = 0;
  int expected_time_count, expected_full_count;

  specify
    $timeskew(posedge ref_clk &&& enabled, posedge data_clk,
              5, time_notifier, , 0:1:0);
    $fullskew(posedge ref_clk &&& enabled, posedge data_clk,
              7, 9, full_notifier, , 0:0:1);

    // Compile the bare triplet with both earlier slots empty.
    $timeskew(posedge idle_ref, posedge data_clk, 5, , , 0:1:0);
    $fullskew(posedge idle_ref, posedge data_clk, 7, 9, , , 0:0:1);
  endspecify

  always @(time_notifier) begin
    if ($time != 15 || time_notifier !== 1'b1)
      $fatal(1, "Unexpected $timeskew notifier value %b at %0t",
             time_notifier, $time);
    time_count++;
  end

  always @(full_notifier) begin
    if ($time != 17 || full_notifier !== 1'b1)
      $fatal(1, "Unexpected $fullskew notifier value %b at %0t",
             full_notifier, $time);
    full_count++;
  end

  initial begin
    if (!$value$plusargs("timeskew=%d", expected_time_count) ||
        !$value$plusargs("fullskew=%d", expected_full_count))
      $fatal(1, "Expected notifier counts must be supplied");

    #10 ref_clk = 1;
    #1 ref_clk = 0;
    #1 enabled = 0;
    #1 ref_clk = 1;

    #11;
    if (time_count != expected_time_count || full_count != expected_full_count)
      $fatal(1, "Notifier counts (%0d,%0d), expected (%0d,%0d)",
             time_count, full_count, expected_time_count, expected_full_count);
    $display("PASSED");
    $finish(0);
  end
endmodule
