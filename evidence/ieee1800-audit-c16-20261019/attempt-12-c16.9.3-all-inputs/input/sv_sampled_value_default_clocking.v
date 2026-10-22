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

  int fails = 0;

  always #5 clk = ~clk;

  default clocking cb @(posedge clk); endclocking

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

    if ($rose(b) !== 1'b0) begin
      fails++;
      $display("FAILED -- $rose(b)=%b after b settled low", $rose(b));
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

  initial begin
    @(negedge clk) d = 1;
    @(negedge clk) begin d = 2; b = 1; end
    @(negedge clk) begin d = 3; b = 0; end
  end

endmodule
