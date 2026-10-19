// M9-SV / R14: a sampled value function with no enclosing event
// control binds to the module's DEFAULT CLOCKING (IEEE 1800-2017
// 16.9.3, clock inference 16.14.6).
//
// Clock inference has three sources, in order: an explicit clocking
// event, the enclosing procedural event control, and the default
// clocking block. Only the middle one was implemented, so `$past(d)'
// written in an `initial' block -- where there is no enclosing event
// control but the module does declare a default clocking -- fell back
// to the unsampled value and answered with d itself.
//
// It now builds the same sampler process any other binding does, on
// `@($ivl_default_clock)', which elaboration resolves to the default
// clocking block's own event.
//
// A module with NO default clocking and no enclosing event control has
// no clock to offer; that case is a warning, not a wrong answer, and is
// covered by tests/negative/sampled_value_unclocked.

module main;

  logic clk = 0;
  int   d   = 0;
  logic b   = 0;
  logic c   = 0;

  int fails = 0;
  int default_changed_wakeups = 0;
  time default_changed_wakeup_times[4];
  int default_stable_wakeups = 0;
  time default_stable_wakeup_times[4];
  int race_changed_wakeups = 0;
  time race_changed_wakeup_times[2];

  always begin
    #5 clk = ~clk;
    // Queue the clock waiters, then update c before they run in Active.
    if (clk && $time == 35) c = 1;
  end

  default clocking cb @(posedge clk); endclocking

  initial forever begin
    // @() observes either value change of the sampled result, not just true.
    @($changed(b));
    if (default_changed_wakeups < 4)
      default_changed_wakeup_times[default_changed_wakeups] = $time;
    default_changed_wakeups++;
  end

  initial forever begin
    @($stable(b));
    if (default_stable_wakeups < 4)
      default_stable_wakeup_times[default_stable_wakeups] = $time;
    default_stable_wakeups++;
  end

  initial forever begin
    @($changed(c));
    if (race_changed_wakeups < 2)
      race_changed_wakeup_times[race_changed_wakeups] = $time;
    race_changed_wakeups++;
  end

  // Reader with no event control of its own: the clock comes from the
  // default clocking block.
  initial begin
    int k;
    // ticks at t=5,15,25,35,45,55; d becomes 1,2,3 on the negedges at
    // t=10,20,30, so at tick k (1-based) d is min(k-1, 3).
    // Read in the ACTIVE region of the tick, which is where a sampled
    // value function is defined to be evaluated: the history shifts
    // under NBA, so the value seen here is the one sampled at the
    // PREVIOUS tick however the scheduler orders the two processes.
    for (k = 1; k <= 6; k++) begin
      @(posedge clk);
      begin
        int want_past;
        want_past = (k <= 1) ? 0 : ((k - 2 > 3) ? 3 : k - 2);
        if ($past(d) !== want_past) begin
          fails++;
          $display("FAILED -- tick %0d: $past(d)=%0d want %0d",
                   k, $past(d), want_past);
        end
      end
    end
    #1;

    if ($rose(b) !== 1'b0) begin
      fails++;
      $display("FAILED -- $rose(b)=%b after b settled low", $rose(b));
    end

    if (default_changed_wakeups != 4) begin
      fails++;
      $display("FAILED -- default-clock $changed event woke %0d times, want 4",
               default_changed_wakeups);
    end
    if (default_changed_wakeup_times[0] != 5
        || default_changed_wakeup_times[1] != 15
        || default_changed_wakeup_times[2] != 25
        || default_changed_wakeup_times[3] != 45) begin
      fails++;
      $display("FAILED -- default-clock $changed wake times %0t,%0t,%0t,%0t; want 5,15,25,45",
               default_changed_wakeup_times[0],
               default_changed_wakeup_times[1],
               default_changed_wakeup_times[2],
               default_changed_wakeup_times[3]);
    end
    if (default_stable_wakeups != 4
        || default_stable_wakeup_times[0] != 5
        || default_stable_wakeup_times[1] != 15
        || default_stable_wakeup_times[2] != 25
        || default_stable_wakeup_times[3] != 45) begin
      fails++;
      $display("FAILED -- default-clock $stable woke %0d times at %0t,%0t,%0t,%0t; want 4 at 5,15,25,45",
               default_stable_wakeups,
               default_stable_wakeup_times[0],
               default_stable_wakeup_times[1],
               default_stable_wakeup_times[2],
               default_stable_wakeup_times[3]);
    end
    if (race_changed_wakeups != 2
        || race_changed_wakeup_times[0] != 45
        || race_changed_wakeup_times[1] != 55) begin
      fails++;
      $display("FAILED -- sampled-region $changed wakes %0d times at %0t,%0t; want 2 at 45,55",
               race_changed_wakeups,
               race_changed_wakeup_times[0],
               race_changed_wakeup_times[1]);
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

  initial begin
    @(negedge clk) d = 1;
    @(negedge clk) d = 2;
    @(negedge clk) d = 3;
  end

  initial begin
    #2 b = 1;
    #14 b = 0;
    #10 b = 1;
  end

endmodule
