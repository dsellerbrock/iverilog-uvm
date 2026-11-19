module issue3800_triggered_delays;
  bit clk, enabled;
  logic [1:0] pulse;
  logic ready;
  bit want_fixed, want_window;
  int fixed_checks, wrapper_checks, window_checks, optional_checks, history_checks;
  int enabled_ticks;

  default clocking cb @(posedge clk iff enabled);
  endclocking

  sequence fixed_delay(c, gate, start, stop);
    @(posedge c iff gate) start ##2 stop;
  endsequence

  sequence wrapped;
    fixed_delay(clk, enabled, pulse, ready);
  endsequence

  sequence bounded_delay(start, stop);
    @(posedge clk) start ##[1:2] stop;
  endsequence

  sequence optional_pulse(start);
    @(posedge clk) start[*0:1];
  endsequence

  sequence leading_delay(c, gate, stop);
    @(posedge c iff gate) ##2 stop;
  endsequence

  sequence leading_window(c, gate, stop);
    @(posedge c iff gate) ##[1:2] stop;
  endsequence

  property enough_history(event ev = $inferred_clock);
    @(ev) (leading_delay(clk, enabled, 1'b1).triggered === (enabled_ticks >= 2))
       && (leading_window(clk, enabled, 1'b1).triggered === (enabled_ticks >= 1));
  endproperty

  fixed_endpoint: assert property (@(posedge clk iff enabled)
    fixed_delay(clk, enabled, pulse, ready).triggered === want_fixed)
    fixed_checks++;
  else $fatal(1, "fixed endpoint at %0t expected %b", $time, want_fixed);

  wrapped_endpoint: assert property (wrapped.triggered === want_fixed)
    wrapper_checks++;
  else $fatal(1, "wrapped endpoint at %0t expected %b", $time, want_fixed);

  bounded_endpoint: assert property (@(posedge clk)
    bounded_delay(pulse, ready).triggered === want_window)
    window_checks++;
  else $fatal(1, "bounded endpoint at %0t expected %b", $time, want_window);

  nonempty_endpoint: assert property (@(posedge clk)
    optional_pulse(pulse).triggered === (pulse === 2'b10))
    optional_checks++;
  else $fatal(1, "optional endpoint at %0t for pulse %b", $time, pulse);

  history_endpoint: assert property (enough_history()) history_checks++;
  else $fatal(1, "endpoint with leading delay at %0t", $time);

  task tick(input bit gate, input logic [1:0] start, input logic stop,
            input bit fixed_end, window_end);
    enabled = gate;
    pulse = start;
    ready = stop;
    want_fixed = fixed_end;
    want_window = window_end;
    #5 clk = 1;
    #5 clk = 0;
    if (gate) enabled_ticks++;
  endtask

  initial begin
    // One pulse starts two bounded matches. The gated fixed match skips tick 2.
    tick(1, 2'b10, 1, 0, 0);
    tick(0, 2'b00, 1, 0, 1);
    tick(1, 2'b00, 1, 0, 1);
    tick(1, 2'bxx, 1, 1, 0);
    // An unknown starting or ending guard must produce a known false result.
    tick(1, 2'b00, 1, 0, 0);
    tick(1, 2'b10, 1, 0, 0);
    tick(1, 2'b00, 0, 0, 0);
    tick(1, 2'b00, 1'bx, 0, 0);
    // Only the longer bounded match ends when the first eligible end is false.
    tick(1, 2'b10, 0, 0, 0);
    tick(1, 2'b00, 0, 0, 0);
    tick(1, 2'b00, 1, 1, 1);
    tick(1, 2'b00, 1, 0, 0);
    if (fixed_checks != 11 || wrapper_checks != 11 ||
        window_checks != 12 || optional_checks != 12 || history_checks != 11)
      $fatal(1, "endpoint checks %0d/%0d/%0d/%0d/%0d",
             fixed_checks, wrapper_checks, window_checks, optional_checks,
             history_checks);
    $display("PASS clocked fixed and bounded triggered endpoints");
    $finish(0);
  end
endmodule
