module top;
  bit clk, reset, left_start, right_start, ready;
  int left_data, right_data, expected, expected_now, bias;
  int passes, failures, copy_passes, copy_failures, now_passes, now_failures;

  always #5 clk = !clk;

  sequence delayed;
    int value;
    ((left_start ##1 (ready, value = left_data)) or
     (right_start ##1 (ready, value = right_data))) ##1 (value == expected);
  endsequence : delayed

  sequence same_tick;
    bit [3:0] value;
    int saved_bias = bias;
    ((left_start ##1 (ready, value = left_data)) or
     (right_start ##1 (ready, value = right_data)))
      ##0 (int'(value) + saved_bias == expected_now);
  endsequence

  assert property (@(posedge clk) disable iff (reset) delayed)
    passes++; else failures++;
  assert property (@(posedge clk) disable iff (reset) delayed)
    copy_passes++; else copy_failures++;
  assert property (@(posedge clk) disable iff (reset) same_tick)
    now_passes++; else now_failures++;

  task tick;
    @(negedge clk);
    #1;
  endtask

  task trial(input bit left_on, right_on, equal_values,
             input int target, input bit should_pass);
    int p, f, cp, cf, np, nf;
    p = passes; f = failures;
    cp = copy_passes; cf = copy_failures;
    np = now_passes; nf = now_failures;

    reset = 0;
    left_start = left_on;
    right_start = right_on;
    ready = 0;
    bias = 3;
    tick();
    if (passes != p || failures != f || copy_passes != cp || copy_failures != cf ||
        now_passes != np || now_failures != nf)
      $fatal(1, "verdict before the assignment tick");

    // Later attempts can start, so they do not fail on a verdict tick.
    left_start = 1;
    right_start = 1;
    ready = 1;
    left_data = 39;
    right_data = equal_values ? 39 : 27;
    expected_now = (target & 15) + 3;
    bias = 8;
    tick();
    if (now_passes != np + should_pass || now_failures != nf + !should_pass)
      $fatal(1, "wrong same-tick verdict for %0d", target);
    if (passes != p || failures != f || copy_passes != cp || copy_failures != cf)
      $fatal(1, "delayed verdict on the assignment tick");

    // The delayed suffix must use the value from the assignment tick.
    left_data = 61;
    right_data = 62;
    expected = target;
    tick();
    if (passes != p + should_pass || failures != f + !should_pass ||
        copy_passes != cp + should_pass || copy_failures != cf + !should_pass)
      $fatal(1, "wrong delayed verdict for %0d (%0d/%0d, copy %0d/%0d)",
             target, passes-p, failures-f, copy_passes-cp, copy_failures-cf);

    reset = 1;
    tick();
  endtask

  initial begin
    trial(1, 0, 0, 39, 1);
    trial(0, 1, 0, 27, 1);
    trial(1, 1, 0, 39, 1);
    trial(1, 1, 0, 27, 1);
    trial(1, 1, 0, 99, 0);
    trial(1, 0, 0, 27, 0);
    trial(1, 1, 1, 39, 1);
    $display("PASSED");
    $finish(0);
  end
endmodule
